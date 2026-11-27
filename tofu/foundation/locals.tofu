# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  environment_key = title(var.environment)

  environment_parent = "folders/${var.google_environment_root_folder_id}"

  teams_output = {
    for team_key, team in var.teams : team_key => {
      display_name               = team.display_name
      environment_root_folder_id = var.google_environment_root_folder_id
      environments = {
        (local.environment_key) = google_folder.teams[team_key].id
      }
      team_folder_id = google_folder.teams[team_key].id
    }
  }

  user_project_override = var.google_quota_project != null

}
