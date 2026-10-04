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

      liveness_probe {
        transport = "HTTP"
        port      = 8080
        path      = "/health"
      }

      readiness_probe {
        transport = "HTTP"
        port      = 8080
        path      = "/health"
      }
    }
  }

  tags = var.tags
}
