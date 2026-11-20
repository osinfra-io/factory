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

run "creates_records_relative_to_the_environment_zone" {
  command = plan

  variables {
    gke_fleet_host = null
    dns_records = [
      { name = "", rrdatas = ["1 aspmx.l.google.com."], ttl = 300, type = "MX" },
      { name = "docs", rrdatas = ["osinfra-io.github.io."], ttl = 300, type = "CNAME" },
    ]
    teams = {
      factory = {
        display_name = "Factory"
      }
    }
  }

  assert {
    condition = (
      google_dns_record_set.records[":MX"].name == "sb.osinfra.io." &&
      google_dns_record_set.records["docs:CNAME"].name == "docs.sb.osinfra.io."
    )
    error_message = "Records must be named relative to the environment zone, with an empty name as the apex."
  }
}

run "rejects_duplicate_records" {
  command = plan

  variables {
    gke_fleet_host = null
    dns_records = [
      { name = "docs", rrdatas = ["a.example."], ttl = 300, type = "CNAME" },
      { name = "docs", rrdatas = ["b.example."], ttl = 300, type = "CNAME" },
    ]
  }

  expect_failures = [var.dns_records]
}
