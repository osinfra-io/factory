mock_provider "google" {
  mock_data "google_logging_project_cmek_settings" {
    defaults = {
      service_account_id = "service-123456789012@gcp-sa-logging.iam.gserviceaccount.com"
    }
  }

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

mock_provider "google" {
  alias = "budget"
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
  bucket               = "sandbox-bootstrap-state"
  google_quota_project = "sandbox-bootstrap"
  prefix               = "foundation"
}

run "plans_the_shared_host_and_state_for_factory" {
  command = plan

  variables {
    gke_fleet_host = null
    teams = {
      factory = {
        display_name = "Factory"
      }
    }
  }

  assert {
    condition = (
      output.shared_vpc.host_project_id == "factory-tfabc-sb" &&
      output.shared_vpc.name == "standard-shared" &&
      local.network_projects["sandbox"] == "123456789" &&
      output.public_dns.dns_name == "sb.osinfra.io." &&
      output.private_dns.dns_name == "private.sb.osinfra.io." &&
      length(output.workload_projects) == 0 &&
      length(output.team_projects) == 0 &&
      length(output.team_dns) == 0 &&
      length(output.regional_subnets) == 0 &&
      length(google_compute_shared_vpc_service_project.workloads) == 0 &&
      length(google_project_iam_member.gke_host_agent) == 0 &&
      length(google_project_service_identity.multi_cluster) == 0 &&
      length(google_artifact_registry_repository.docker_remote) == 0 &&
      length(google_artifact_registry_repository.docker_standard) == 0 &&
      length(google_artifact_registry_repository.docker_virtual) == 0 &&
      output.team_state["factory"].bucket == "factory-567188438944-state-sb" &&
      google_kms_crypto_key_iam_member.state_storage["factory"].role == "roles/cloudkms.cryptoKeyEncrypterDecrypter" &&
      length(google_service_account.registry_publishers) == 0
    )
    error_message = "The shared host must live in the Factory team folder while keeping the environment-scoped state bucket name."
  }
}

run "provisions_state_for_every_onboarded_team" {
  command = plan

  variables {
    gke_fleet_host = null
    teams = {
      factory = {
        display_name = "Factory"
      }
      other = {
        display_name = "Other"
      }
    }
  }

  assert {
    condition = (
      tomap({ for team, state in output.team_state : team => state.bucket }) == tomap({
        factory = "factory-567188438944-state-sb"
        other   = "other-567188438944-state-sb"
      }) &&
      toset(keys(google_kms_crypto_key.team_state)) == toset(["factory", "other"]) &&
      toset(keys(google_kms_crypto_key_iam_member.state_storage)) == toset(["factory", "other"]) &&
      length(output.workload_projects) == 0
    )
    error_message = "Every onboarded team must get its own encrypted state bucket, even without a workload project."
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

run "ports_the_shared_vpc_for_the_factory_locations" {
  command = plan

  assert {
    condition = (
      output.shared_vpc.name == "standard-shared" &&
      google_compute_shared_vpc_service_project.workloads["factory"].host_project == output.shared_vpc.host_project_id &&
      google_compute_shared_vpc_service_project.workloads["factory"].service_project == output.workload_projects["factory"].id &&
      output.workload_projects["factory"].id == "factory-tfabc-sb" &&
      toset(keys(output.regional_subnets["us-east1"])) == toset(["factory-us-east1-b", "factory-us-east1-c", "factory-us-east1-d"]) &&
      toset(keys(output.regional_subnets["us-east4"])) == toset(["factory-us-east4-a", "factory-us-east4-b", "factory-us-east4-c"]) &&
      output.regional_subnets["us-east1"]["factory-us-east1-b"].location == "us-east1-b" &&
      output.regional_subnets["us-east1"]["factory-us-east1-b"].ranges == {
        control_plane = "10.63.192.0/28"
        nodes         = "10.60.0.0/20"
        pods          = "10.0.0.0/15"
        services      = "10.61.224.0/20"
      } &&
      output.regional_subnets["us-east1"]["factory-us-east1-b"].service_project_number == "123456789012" &&
      toset(flatten([
        for region in values(output.regional_subnets) : [for key, subnet in region : key if subnet.enable_gke_hub_host]
      ])) == toset(["factory-us-east1-b"]) &&
      toset(keys(google_project_service_identity.multi_cluster)) == toset(["factory"]) &&
      output.team_dns["factory"].dns_name == "factory.sb.osinfra.io." &&
      length(output.cloud_sql_instances) == 0 &&
      length(google_artifact_registry_repository.docker_standard) == 0
    )
    error_message = "Factory's workload project must plan DNS, six cluster networks, and a fleet host without enabling Cloud SQL or a registry."
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
    gke_fleet_host = {
      location = "us-east1-b"
      team     = "factory"
    }
    runtime_project_access = {
      factory = {
        "roles/container.admin" = ["serviceAccount:runtime@example.iam.gserviceaccount.com"]
      }
    }
    teams = {
      factory = {
        artifact_registry = {
          github_repository_ids = ["67890"]
          readers               = ["group:registry-readers@example.com"]
        }
        display_name = "Factory"
        google_project = {
          administrators = ["group:project-editors@example.com"]
          services       = ["pubsub.googleapis.com"]
        }
        workload_project = {
          cloud_sql = {
            authentik = {
              database_version = "POSTGRES_16"
              machine_tier     = "db-custom-1-3840"
              regions          = ["us-east1"]
            }
          }
          kubernetes_engine = {
            dns_writers = ["group:dns-writers@example.com"]
            locations = {
              us-east1-b = {
                subnet = var.teams["factory"].workload_project.kubernetes_engine.locations["us-east1-b"].subnet
              }
            }
          }
        }
      }
      other = {
        artifact_registry = {
          readers = ["group:member-registry-readers@example.com"]
        }
        display_name = "Member"
        workload_project = {
          kubernetes_engine = {
            registry_pullers = ["group:member-node-pullers@example.com"]
            locations = {
              us-east1-b = {
                subnet = {
                  ip_cidr_range          = "10.90.0.0/20"
                  master_ipv4_cidr_block = "10.90.16.0/28"
                  pod_ip_cidr_range      = "10.91.0.0/16"
                  services_ip_cidr_range = "10.92.0.0/20"
                }
              }
            }
          }
        }
      }
    }
  }

  assert {
    condition = (
      output.cloud_sql_instances["factory/authentik"].project_id == output.workload_projects["factory"].id &&
      output.cloud_sql_instances["factory/authentik"].database_version == "POSTGRES_16" &&
      output.cloud_sql_instances["factory/authentik"].machine_tier == "db-custom-1-3840" &&
      output.cloud_sql_instances["factory/authentik"].regions == toset(["us-east1"]) &&
      google_service_networking_connection.private_services["sandbox"].service == "servicenetworking.googleapis.com" &&
      google_compute_shared_vpc_service_project.external["approved-service-project"].host_project == output.shared_vpc.host_project_id &&
      google_project_iam_member.gke_host_agent["factory"].member == output.regional_subnets["us-east1"]["factory-us-east1-b"].gke_service_agent &&
      google_project_service_identity.gke["factory"].service == "container.googleapis.com" &&
      google_project_iam_member.runtime[jsonencode(["factory", "roles/container.admin", "serviceAccount:runtime@example.iam.gserviceaccount.com"])].role == "roles/container.admin" &&
      google_project_service_identity.multi_cluster["factory"].service == "multiclusterservicediscovery.googleapis.com" &&
      output.regional_subnets["us-east1"]["factory-us-east1-b"].enable_gke_hub_host &&
      !output.regional_subnets["us-east1"]["other-us-east1-b"].enable_gke_hub_host &&
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

run "rejects_a_fleet_host_without_a_requested_location" {
  command = plan

  variables {
    gke_fleet_host = {
      location = "us-east1-a"
      team     = "factory"
    }
  }

  expect_failures = [var.gke_fleet_host]
}

run "rejects_a_cluster_with_an_invalid_subnet" {
  command = plan

  variables {
    teams = {
      factory = {
        display_name = "Factory"
        workload_project = {
          kubernetes_engine = {
            locations = {
              us-east1-b = {
                subnet = merge(var.teams["factory"].workload_project.kubernetes_engine.locations["us-east1-b"].subnet, {
                  pod_ip_cidr_range = "2001:db8::/64"
                })
              }
            }
          }
        }
      }
    }
  }

  expect_failures = [var.teams]
}
