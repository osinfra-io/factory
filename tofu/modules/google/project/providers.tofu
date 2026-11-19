terraform {
  required_providers {
    google = {
      source                = "hashicorp/google"
      configuration_aliases = [google.budget]
    }
    google-beta = {
      source = "hashicorp/google-beta"
    }
  }
}
