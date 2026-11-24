mock_provider "google" {}
mock_provider "random" {}

mock_provider "terraform" {
  mock_data "terraform_remote_state" {
    defaults = {
      outputs = {
        cloud_sql_instances = {
          "factory/authentik" = {
            database_version = "POSTGRES_16"
            instance_name    = "authentik"
            machine_tier     = "db-custom-1-3840"
            project_id       = "factory-workloads-sb"
            regions          = ["us-east1"]
            team             = "factory"
          }
          "factory/other-region" = {
            database_version = "POSTGRES_16"
            instance_name    = "other-region"
            machine_tier     = "db-custom-1-3840"
            project_id       = "factory-workloads-sb"
            regions          = ["us-east4"]
            team             = "factory"
          }
        }
        private_dns = {
          dns_name = "private.sb.osinfra.io."
          name     = "private-sb-osinfra-io"
        }
        regional_subnets = {
          us-east1 = {
            factory-us-east1-b = {
              enable_gke_hub_host = true
              gke_service_agent   = "serviceAccount:service-123456789012@container-engine-robot.iam.gserviceaccount.com"
              location            = "us-east1-b"
              ranges = {
                control_plane = "10.80.16.0/28"
                nodes         = "10.80.0.0/20"
                pods          = "10.81.0.0/16"
                services      = "10.82.0.0/20"
              }
              service_project_id     = "factory-workloads-sb"
              service_project_number = "123456789012"
              team                   = "factory"
            }
          }
          us-east4 = {}
        }
        shared_vpc = {
          host_project_id = "factory-tfabc-sb"
          name            = "standard-shared"
        }
      }
    }
  }
}

variables {
  bucket = "sandbox-bootstrap-state"
}

run "provides_the_runtime_network_and_private_database" {
  command = apply

  assert {
    condition = (
      data.terraform_remote_state.assembly.workspace == replace(terraform.workspace, "/^us-east[14]-assembly-/", "assembly-main-") &&
      data.terraform_remote_state.assembly.config.bucket == var.bucket &&
      data.terraform_remote_state.assembly.config.prefix == "assembly"
    )
    error_message = "Regional workspaces must read the main Assembly state for their own environment."
  }

  assert {
    condition = startswith(terraform.workspace, "us-east1-") ? (
      output.runtime_networks["factory-us-east1-b"].subnet == "factory-us-east1-b" &&
      output.runtime_networks["factory-us-east1-b"].enable_gke_hub_host &&
      output.runtime_networks["factory-us-east1-b"].private_endpoint_subnetwork == "factory-us-east1-b-master" &&
      output.runtime_networks["factory-us-east1-b"].host_project_id == "factory-tfabc-sb" &&
      output.runtime_networks["factory-us-east1-b"].project_id == "factory-workloads-sb" &&
      google_compute_subnetwork_iam_member.workloads["factory-us-east1-b/gke"].member == "serviceAccount:service-123456789012@container-engine-robot.iam.gserviceaccount.com" &&
      !contains(keys(output.cloud_sql_instances), "factory/other-region") &&
      output.cloud_sql_instances["factory/authentik"].host == "authentik.us-east1.sql.factory.private.sb.osinfra.io."
      ) : (
      length(output.runtime_networks) == 0 &&
      !contains(keys(output.cloud_sql_instances), "factory/authentik") &&
      output.cloud_sql_instances["factory/other-region"].host == "other-region.us-east4.sql.factory.private.sb.osinfra.io."
    )
    error_message = "The regional workspace must only create Runtime subnet references and database DNS for its own region."
  }
}
