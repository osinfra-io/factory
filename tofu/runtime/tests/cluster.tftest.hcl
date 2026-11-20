mock_provider "google" {}
mock_provider "random" {
  mock_resource "random_id" {
    defaults = {
      hex = "abcd1234"
    }
  }
}

mock_provider "terraform" {
  mock_data "terraform_remote_state" {
    defaults = {
      outputs = {
        runtime_networks = {
          factory-us-east1-b = {
            enable_gke_hub_host         = true
            host_project_id             = "factory-tfabc-sb"
            location                    = "us-east1-b"
            network                     = "standard-shared"
            private_endpoint_subnetwork = "factory-us-east1-b-master"
            project_id                  = "factory-tfdef-sb"
            region                      = "us-east1"
            subnet                      = "factory-us-east1-b"
            team                        = "factory"
          }
          factory-us-east1-c = {
            enable_gke_hub_host         = false
            host_project_id             = "factory-tfabc-sb"
            location                    = "us-east1-c"
            network                     = "standard-shared"
            private_endpoint_subnetwork = "factory-us-east1-c-master"
            project_id                  = "factory-tfdef-sb"
            region                      = "us-east1"
            subnet                      = "factory-us-east1-c"
            team                        = "factory"
          }
        }
      }
    }
  }
}

variables {
  bucket = "sandbox-bootstrap-state"
}

run "creates_only_the_workspace_zone_cluster" {
  command = plan

  assert {
    condition     = keys(local.clusters) == ["factory-us-east1-b"]
    error_message = "A zonal Runtime workspace must create only its own cluster."
  }
}
