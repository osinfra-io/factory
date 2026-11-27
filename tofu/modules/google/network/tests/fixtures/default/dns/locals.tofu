# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  labels = {
    "mock-key" = "mock-value"
  }

  private_test_private_visibility_config_networks = ["https://www.googleapis.com/compute/v1/projects/${var.project}/global/networks/mock-vpc"]
}
