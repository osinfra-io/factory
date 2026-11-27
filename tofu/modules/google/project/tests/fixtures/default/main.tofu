# Required Providers
# https://opentofu.org/docs/language/providers/requirements

terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
    }
    google-beta = {
      source = "hashicorp/google-beta"
    }
  }
}

# Google Project
# https://github.com/osinfra-io/pt-arche-google-project

module "google_project" {
  source = "../../../"

  providers = {
    google.budget = google
  }

  billing_account                 = "000000-000000-000000"
  cis_2_2_logging_sink            = local.logging_sink
  cis_2_2_logging_sink_project_id = local.logging_sink_project_id
  folder_id                       = "0000000000000"

  labels = {
    "mock-key" = "mock-value"
  }

  prefix = "mock"

  services = [
    "mock.googleapis.com"
  ]
}

resource "terraform_data" "logging_project" {
  lifecycle {
    enabled = var.defer_logging_sink
  }

  input = var.cis_2_2_logging_sink_project_id
}
