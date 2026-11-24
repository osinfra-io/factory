mock_provider "google" {
  mock_data "google_logging_project_settings" {
    defaults = {
      kms_service_account_id     = "kms-mock@gcp-sa-logging.iam.gserviceaccount.com"
      logging_service_account_id = "service-mock@gcp-sa-logging.iam.gserviceaccount.com"
    }
  }

  mock_resource "google_logging_project_sink" {
    defaults = {
      writer_identity = "serviceAccount:mock-cis-2-2-logging-sink@mock.iam.gserviceaccount.com"
    }
  }
}

mock_provider "google-beta" {
  mock_resource "google_project_service_identity" {
    defaults = {
      email = "service-mock@gcp-sa-logging.iam.gserviceaccount.com"
    }
  }
}

run "default" {
  command = apply

  module {
    source = "./tests/fixtures/default"
  }

  variables {
    cis_2_2_logging_sink_project_id = "mock-logging-sink-project"
  }

  assert {
    condition     = can(regex("^mock-tf[0-9a-f]{3}-", module.google_project.id))
    error_message = "Generated project IDs must default to three random hexadecimal digits after tf."
  }
}

run "logging" {
  command = plan

  module {
    source = "./tests/fixtures/logging"
  }

  assert {
    condition     = output.cis_2_2_logging_bucket_locked
    error_message = "The CIS 2.2 logging bucket must be locked by default"
  }
}

run "grants_key_access_to_logging_cmek_identity" {
  command = apply

  providers = {
    google        = google
    google.budget = google
    google-beta   = google-beta
  }

  variables {
    billing_account   = "000000-000000-000000"
    folder_id         = "0000000000000"
    random_project_id = false
  }

  assert {
    condition     = google_kms_crypto_key_iam_member.cis_2_2_logging_sink.member == "serviceAccount:kms-mock@gcp-sa-logging.iam.gserviceaccount.com"
    error_message = "The logging bucket key must be granted to the CMEK service account returned by project settings."
  }
}

run "plans_an_external_logging_sink_with_a_deferred_project_id" {
  command = plan

  module {
    source = "./tests/fixtures/default"
  }

  variables {
    cis_2_2_logging_sink_project_id = "mock-logging-sink-project"
    defer_logging_sink              = true
  }

  assert {
    condition     = output.cis_2_2_logging_bucket_locked == null
    error_message = "A deferred external logging project ID must not prevent planning or create a local logging bucket."
  }
}

variables {
  environment = "sandbox"
}
