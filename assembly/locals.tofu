locals {
  foundation_workspace = "foundation-main-${var.environment}"

  team_folder_ids = {
    for team in keys(var.teams) : team => data.terraform_remote_state.foundation.outputs.teams[team].team_folder_id
  }
}
