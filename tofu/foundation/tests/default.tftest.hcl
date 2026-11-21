mock_provider "google" {}

run "factory_team" {
  command = apply

  variables {
    environment                       = "sandbox"
    google_environment_root_folder_id = "567188438944"
    google_quota_project              = "bootstrap-567188438944-sb"
    teams = {
      factory = {
        display_name = "Factory"
      }
    }
  }

  assert {
    condition     = output.teams["factory"].display_name == "Factory" && output.teams["factory"].environment_root_folder_id == "567188438944" && contains(keys(output.teams["factory"].environments), "Sandbox") && output.teams["factory"].environments["Sandbox"] == output.teams["factory"].team_folder_id
    error_message = "Foundation must publish the single Factory team under the existing sandbox environment folder."
  }
}

run "rejects_other_teams" {
  command = plan

  variables {
    environment                       = "sandbox"
    google_environment_root_folder_id = "567188438944"
    google_quota_project              = "bootstrap-567188438944-sb"
    teams = {
      assembly = {
        display_name = "Assembly"
      }
    }
  }

  expect_failures = [var.teams]
}
