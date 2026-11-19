mock_provider "google" {
  mock_data "google_storage_project_service_account" {
    defaults = {
      member = "serviceAccount:service-123456789012@gs-project-accounts.iam.gserviceaccount.com"
    }
  }

  mock_resource "google_iam_workload_identity_pool" {
    defaults = {
      name = "projects/123456789012/locations/global/workloadIdentityPools/github-registry-publishers"
    }
  }

  mock_resource "google_logging_project_sink" {
    defaults = {
      writer_identity = "serviceAccount:logging@example.iam.gserviceaccount.com"
    }
  }

  mock_resource "google_project" {
    defaults = {
      number = "123456789012"
    }
  }

  mock_resource "google_service_account" {
    defaults = {
      email = "factory-publisher@factory-tfabc-sb.iam.gserviceaccount.com"
      name  = "projects/factory-tfabc-sb/serviceAccounts/factory-publisher@factory-tfabc-sb.iam.gserviceaccount.com"
    }
  }
}

mock_provider "google-beta" {
  mock_resource "google_project_service_identity" {
    defaults = {
      member = "serviceAccount:service-123456789012@container-engine-robot.iam.gserviceaccount.com"
    }
  }
}

mock_provider "random" {
  mock_resource "random_id" {
    defaults = {
      hex = "tfabcd"
    }
  }
}

mock_provider "terraform" {
  mock_data "terraform_remote_state" {
    defaults = {
      outputs = {
        environment_root_folder_id = "567188438944"
        teams = {
          factory = { team_folder_id = "folders/123456789" }
          other   = { team_folder_id = "folders/987654321" }
        }
      }
    }
  }
}

variables {
  bucket = "sandbox-bootstrap-state"
  prefix = "foundation"
}

run "plans_only_the_shared_host_for_the_current_factory_team" {
  command = plan

  assert {
    condition = (
      output.shared_vpc.host_project_id == "factory-tfabc-sb" &&
      output.shared_vpc.name == "standard-shared" &&
      output.public_dns.dns_name == "sb.osinfra.io." &&
      output.private_dns.dns_name == "private.sb.osinfra.io." &&
      length(output.workload_projects) == 0 &&
      length(output.team_projects) == 0 &&
      length(output.team_dns) == 0 &&
      length(output.regional_subnets) == 0 &&
      length(google_compute_shared_vpc_service_project.workloads) == 0 &&
      length(google_project_iam_member.gke_host_agent) == 0 &&
      length(output.artifact_registries) == 0 &&
      length(output.team_state) == 0
    )
    error_message = "The current Factory team must get the shared host baseline without provisioning team or workload infrastructure."
  }
}

run "plans_separate_team_state_access" {
  command = plan

  variables {
    teams = {
      factory = {
        display_name = "Factory"
        opentofu_state = {
          readers = ["group:state-readers@example.com", "group:state-writers@example.com"]
          writers = ["group:state-writers@example.com"]
        }
      }
    }
  }

  assert {
    condition = (
      google_storage_bucket_iam_member.state_readers["factory/group:state-readers@example.com"].role == "roles/storage.objectViewer" &&
      google_kms_crypto_key_iam_member.state_readers["factory/group:state-readers@example.com"].role == "roles/cloudkms.cryptoKeyDecrypter" &&
      google_storage_bucket_iam_member.state_writers["factory/group:state-writers@example.com"].role == "roles/storage.objectAdmin" &&
      google_kms_crypto_key_iam_member.state_writers["factory/group:state-writers@example.com"].role == "roles/cloudkms.cryptoKeyEncrypterDecrypter" &&
      !contains(keys(google_storage_bucket_iam_member.state_readers), "factory/group:state-writers@example.com") &&
      output.team_state["factory"].bucket == "factory-567188438944-state-sb"
    )
    error_message = "Team state grants must distinguish read and write access to the team's encrypted bucket."
  }
}

run "reads_only_sandbox_foundation_for_declared_teams" {
  command = plan

  assert {
    condition = (
      data.terraform_remote_state.foundation.workspace == "foundation-main-sandbox" &&
      data.terraform_remote_state.foundation.config["bucket"] == var.bucket &&
      data.terraform_remote_state.foundation.config["prefix"] == var.prefix &&
      tomap(output.team_folder_ids) == tomap({ factory = "folders/123456789" })
    )
    error_message = "Assembly must read only the declared team folder from the Sandbox Foundation backend."
  }
}

run "ports_the_shared_vpc_for_the_factory_location" {
  command = plan

  variables {
    teams = {
      factory = {
        display_name = "Factory"
        kubernetes_engine = {
          locations = { us-east1-b = {} }
        }
      }
    }
  }

  assert {
    condition = (
      output.shared_vpc.name == "standard-shared" &&
      google_compute_shared_vpc_service_project.workloads["factory"].host_project == output.shared_vpc.host_project_id &&
      google_compute_shared_vpc_service_project.workloads["factory"].service_project == output.workload_projects["factory"].id &&
      output.workload_projects["factory"].id == "factory-work-tfab-sb" &&
      output.regional_subnets["us-east1"]["factory-us-east1-b"].location == "us-east1-b" &&
      output.regional_subnets["us-east1"]["factory-us-east1-b"].service_project_number == "123456789012" &&
      output.team_dns["factory"].dns_name == "factory.sb.osinfra.io."
    )
    error_message = "The Factory team's requested cluster must get a service project, Shared VPC attachment, subnet allocation, and team DNS."
  }
}

run "rejects_production" {
  command = plan

  variables {
    environment = "production"
  }

  expect_failures = [var.environment]
}

run "ports_opt_in_corpus_services" {
  command = plan

  variables {
    external_service_projects  = ["approved-service-project"]
    github_repository_owner_id = "12345"
    runtime_project_access = {
      factory = {
        "roles/container.admin" = ["serviceAccount:runtime@example.iam.gserviceaccount.com"]
      }
    }
    cluster_subnets = {
      factory = var.cluster_subnets["factory"]
      other   = { us-east1-b = { control_plane = "10.90.16.0/28", nodes = "10.90.0.0/20", pods = "10.91.0.0/16", services = "10.92.0.0/20" } }
    }
    teams = {
      factory = {
        artifact_registry = {
          github_repository_ids = ["67890"]
          readers               = ["group:registry-readers@example.com"]
        }
        cloud_sql = {
          authentik = {
            database_version = "POSTGRES_16"
            machine_tier     = "db-custom-1-3840"
            regions          = ["us-east1"]
          }
        }
        display_name = "Factory"
        google_project = {
          administrators = ["group:project-editors@example.com"]
          services       = ["pubsub.googleapis.com"]
        }
        kubernetes_engine = {
          dns_writers = ["group:dns-writers@example.com"]
          locations = {
            us-east1-b = { enable_gke_hub_host = true }
          }
        }
      }
      other = {
        artifact_registry = {
          readers = ["group:member-registry-readers@example.com"]
        }
        display_name = "Member"
        kubernetes_engine = {
          locations        = { us-east1-b = {} }
          registry_pullers = ["group:member-node-pullers@example.com"]
        }
      }
    }
  }

  assert {
    condition = (
      output.cloud_sql_instances["factory/authentik"].project_id == output.workload_projects["factory"].id &&
      google_service_networking_connection.private_services["sandbox"].service == "servicenetworking.googleapis.com" &&
      google_compute_shared_vpc_service_project.external["approved-service-project"].host_project == output.shared_vpc.host_project_id &&
      google_project_iam_member.gke_host_agent["factory"].member == output.regional_subnets["us-east1"]["factory-us-east1-b"].gke_service_agent &&
      google_project_service_identity.gke["factory"].service == "container.googleapis.com" &&
      google_project_iam_member.runtime[jsonencode(["factory", "roles/container.admin", "serviceAccount:runtime@example.iam.gserviceaccount.com"])].role == "roles/container.admin" &&
      google_project_service_identity.multi_cluster["factory"].service == "multiclusterservicediscovery.googleapis.com" &&
      output.team_projects["factory"].id != output.workload_projects["factory"].id
    )
    error_message = "Cloud SQL and fleet integrations must use the workload project, not the separate team project."
  }

  assert {
    condition = (
      google_artifact_registry_repository.docker_virtual["factory"].mode == "VIRTUAL_REPOSITORY" &&
      contains(google_artifact_registry_repository_iam_binding.readers["factory"].members, "group:member-node-pullers@example.com") &&
      !contains(google_artifact_registry_repository_iam_binding.readers["factory"].members, "group:member-registry-readers@example.com") &&
      !contains(google_artifact_registry_repository_iam_binding.readers["other"].members, "group:registry-readers@example.com") &&
      google_dns_managed_zone_iam_member.team_writers["factory/group:dns-writers@example.com"].managed_zone == output.team_dns["factory"].name &&
      google_iam_workload_identity_pool_provider.github["sandbox"].attribute_condition == "assertion.repository_owner_id == \"12345\"" &&
      google_iam_workload_identity_pool_provider.github["sandbox"].attribute_mapping["attribute.repository_id"] == "assertion.repository_id" &&
      strcontains(google_service_account_iam_member.github_publishers["factory/67890"].member, "/attribute.repository_id/67890")
    )
    error_message = "The virtual registry must use a publisher bound to the exact trusted GitHub owner and repository IDs."
  }
}

run "rejects_a_cluster_without_an_allocation" {
  command = plan

  variables {
    cluster_subnets = {}
    teams = {
      factory = {
        display_name = "Factory"
        kubernetes_engine = {
          locations = { us-east1-b = {} }
        }
      }
    }
  }

  expect_failures = [var.teams]
}
