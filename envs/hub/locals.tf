# google applies these through default_labels and aws through default_tags.
# azurerm has neither, so Azure resources pass this map in themselves.
locals {
  common_tags = {
    project      = var.project
    env          = var.env
    owner        = var.owner
    estate       = "hub"
    "managed-by" = "terraform"
  }
}

# Only runs on main can sign in. Pull requests and other branches carry a
# different subject and are refused.
locals {
  github_subject = "${var.github_sub_prefix}:ref:refs/heads/main"
}
