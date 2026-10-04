terraform {
  required_version = ">= 1.11"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.67"
    }
  }

  # All four roots keep state in the same bucket under their own prefix. A
  # plan in one root cannot see or change another root's resources. This
  # estate's state still lives in GCS, so the backend signs in with gcloud
  # application default credentials, not with this cloud's own login.
  backend "gcs" {
    bucket = "moyo-platform-tfstate"
    prefix = "multicloud-platform/aws"
  }
}
