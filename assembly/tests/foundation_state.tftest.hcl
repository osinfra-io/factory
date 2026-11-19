mock_provider "terraform" {
  mock_data "terraform_remote_state" {
    defaults = {
      outputs = {
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

run "reads_only_sandbox_foundation_for_declared_teams" {
  command = apply

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

run "rejects_production" {
  command = plan

  variables {
    environment = "production"
  }

  expect_failures = [var.environment]
}
