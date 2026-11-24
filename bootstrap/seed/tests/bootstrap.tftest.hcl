mock_provider "google" {}

run "sandbox_seed" {
  command = plan

  override_module {
    target = module.core_helpers
    outputs = {
      env         = "sb"
      environment = "sandbox"
      labels      = {}
    }
  }

  assert {
    condition     = google_project.bootstrap.folder_id == "567188438944" && google_project.bootstrap.project_id == "bootstrap-567188438944-sb"
    error_message = "The seed project must remain inside the existing sandbox folder."
  }

  assert {
    condition     = google_project.bootstrap.auto_create_network == false
    error_message = "The seed must not create an implicit default network."
  }

  assert {
    condition     = google_storage_bucket.state.uniform_bucket_level_access && google_storage_bucket.state.public_access_prevention == "enforced"
    error_message = "The remote state bucket must not allow public or object-ACL access."
  }
}

run "non_production_seed" {
  command = plan

  override_module {
    target = module.core_helpers
    outputs = {
      env         = "nonprod"
      environment = "non-production"
      labels      = {}
    }
  }

  assert {
    condition     = google_project.bootstrap.folder_id == "851025769053" && google_project.bootstrap.project_id == "bootstrap-851025769053-nonprod"
    error_message = "The seed project must live in the Non-Production folder."
  }
}

run "production_seed" {
  command = plan

  override_module {
    target = module.core_helpers
    outputs = {
      env         = "prod"
      environment = "production"
      labels      = {}
    }
  }

  assert {
    condition     = google_project.bootstrap.folder_id == "1093631952702" && google_project.bootstrap.project_id == "bootstrap-1093631952702-prod"
    error_message = "The seed project must live in the Production folder."
  }
}
