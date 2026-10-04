terraform {
  required_version = ">= 1.11"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.5"
    }
  }

  # All four roots keep state in the same bucket under their own prefix. A
  # plan in one root cannot see or change another root's resources.
  backend "gcs" {
    bucket = "moyo-platform-tfstate"
    prefix = "multicloud-platform/hub"
  }
}
