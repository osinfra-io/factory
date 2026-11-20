terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
    }
  }
}

provider "google" {
  billing_project       = var.google_quota_project
  user_project_override = local.user_project_override
}
