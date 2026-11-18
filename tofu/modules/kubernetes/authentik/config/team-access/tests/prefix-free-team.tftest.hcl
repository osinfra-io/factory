run "prefix_free_team_key" {
  command = plan

  variables {
    environment = "sandbox"
    teams = {
      factory = {
        authentik_groups = {
          admins = {
            description = "Local administrators"
            label       = "Admins"
          }
        }
      }
    }
  }

  assert {
    condition     = output.application_groups["factory/admins"].name == "factory: Admins"
    error_message = "A prefix-free team key must produce its qualified Authentik group name."
  }
}
