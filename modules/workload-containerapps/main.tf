# Everything the Azure estate creates goes in one resource group, so deleting
# the group removes the estate. Tags are passed to every resource because
# azurerm has no provider-level default.
resource "azurerm_resource_group" "this" {
  name     = "rg-${var.name}"
  location = var.location
  tags     = var.tags
}

# Basic is the cheapest SKU. It has no image scanning and no registry-wide
# immutable tags, so images are pushed under unique tags and run by digest.
# The admin user stays off and pulls go through the managed identity.
resource "azurerm_container_registry" "this" {
  name                = var.registry_name
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  sku                 = "Basic"
  admin_enabled       = false
  tags                = var.tags
}

# User-assigned rather than system-assigned, so AcrPull is in place before
# the app's first image pull. Later it is also the identity the collector
# exchanges for a short-lived Google token.
resource "azurerm_user_assigned_identity" "app" {
  name                = "id-${var.name}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  tags                = var.tags
}

resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.this.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
  principal_type       = "ServicePrincipal"
}

# Consumption profile only, so apps scale to zero and nothing bills by the
# hour. No VNet this time, which also means no managed resource group with a
# load balancer and public IP. No Log Analytics workspace either, because the
# app's logs go to the hub through the collector.
resource "azurerm_container_app_environment" "this" {
  name                = "cae-${var.name}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location

  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }

  tags = var.tags
}

# Nothing to run until an image has been pushed, so the app only exists once
# an image reference is passed in.
resource "azurerm_container_app" "this" {
  count = var.image == "" ? 0 : 1

  name                         = "ca-${var.name}"
  container_app_environment_id = azurerm_container_app_environment.this.id
  resource_group_name          = azurerm_resource_group.this.name
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.app.id]
  }

  registry {
    server   = azurerm_container_registry.this.login_server
    identity = azurerm_user_assigned_identity.app.id
  }

  ingress {
    external_enabled = true
    target_port      = 8080

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = 0
    max_replicas = 2

    container {
      name   = "api"
      image  = var.image
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name  = "CLOUD"
        value = "azure"
      }

      # With a collector next to it, the app also sends its logs there.
      dynamic "env" {
        for_each = var.collector_image == "" ? [] : [1]
        content {
          name  = "OTEL_EXPORTER_OTLP_ENDPOINT"
          value = "http://127.0.0.1:4318"
        }
      }

      liveness_probe {
        transport = "HTTP"
        port      = 8080
        path      = "/health"
      }

      # azurerm's defaults want three successes ten seconds apart, which kept
      # a started replica out of traffic for about 30 seconds on every cold
      # start. One success checked every 5 seconds is enough for an app with
      # no dependencies to warm up.
      readiness_probe {
        transport               = "HTTP"
        port                    = 8080
        path                    = "/health"
        interval_seconds        = 5
        success_count_threshold = 1
      }
    }

    # The collector, the same image as in the other two estates. It signs in
    # to Google with the baked-in Azure credential config, which points at
    # the shim below.
    #
    # Container Apps only accepts set CPU and memory pairs for the whole
    # app, so with three containers at 0.25 vCPU and 0.5 Gi each the app is
    # 0.75 vCPU and 1.5 Gi. That is three times the app alone, billed only
    # while a replica is running.
    dynamic "container" {
      for_each = var.collector_image == "" ? [] : [var.collector_image]
      content {
        name   = "collector"
        image  = container.value
        cpu    = 0.25
        memory = "0.5Gi"

        env {
          name  = "CLOUD"
          value = "azure"
        }

        env {
          name  = "GOOGLE_APPLICATION_CREDENTIALS"
          value = "/etc/platform/azure-credential-config.json"
        }
      }
    }

    # Adds the per-container identity header Google's library cannot read
    # from the environment, and hands it the managed identity token. Runs
    # from the app image, which already has Python.
    dynamic "container" {
      for_each = var.collector_image == "" ? [] : [1]
      content {
        name    = "credential-shim"
        image   = var.image
        cpu     = 0.25
        memory  = "0.5Gi"
        command = ["python", "-c", file("${path.module}/../../collector/credential_shim.py")]

        env {
          name  = "SHIM_MODE"
          value = "azure"
        }

        env {
          name  = "AZURE_CLIENT_ID"
          value = azurerm_user_assigned_identity.app.client_id
        }
      }
    }
  }

  tags = var.tags

  # CI owns the image after the first deploy. Without this every plan would
  # roll the app back to var.image.
  lifecycle {
    ignore_changes = [template[0].container[0].image]
  }
}
