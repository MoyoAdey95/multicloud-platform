# google applies these through default_labels and aws through default_tags.
# azurerm has neither, so Azure resources pass this map in themselves.
locals {
  common_tags = {
    project      = var.project
    env          = var.env
    owner        = var.owner
    estate       = "aws"
    "managed-by" = "terraform"
  }
}

# The identities that deploy or write trust only runs on main. Other branches
# carry a different subject and are refused.
locals {
  github_subject = "${var.github_sub_prefix}:ref:refs/heads/main"

  # Pull request runs carry this subject. Only the read-only plan identities
  # trust it.
  github_pr_subject = "${var.github_sub_prefix}:pull_request"
}
