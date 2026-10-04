# google applies these through default_labels and aws through default_tags.
# azurerm has neither, so Azure resources pass this map in themselves.
locals {
  common_tags = {
    project      = var.project
    env          = var.env
    owner        = var.owner
    estate       = "gcp"
    "managed-by" = "terraform"
  }
}
