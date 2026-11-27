# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  # Production state provides shared team metadata; environment state provides scoped folders
  # and identity groups for the current deployment environment.
  all_team_keys = toset(concat(
    keys(local.production_teams),
    keys(local.environment_teams)
  ))

  all_teams = {
    for team_key in local.all_team_keys : team_key => merge(
      try(local.production_teams[team_key], {}),
      try(local.environment_teams[team_key], {}),
      {
        billing_users_group = try(local.environment_teams[team_key].billing_users_group, null) != null ? local.environment_teams[team_key].billing_users_group : try(local.production_teams[team_key].billing_users_group, null)
        environments = merge(
          try(local.production_teams[team_key].environments, {}),
          try(local.environment_teams[team_key].environments, {})
        )
        github_repositories = merge(
          try(local.production_teams[team_key].github_repositories, {}),
          try(local.environment_teams[team_key].github_repositories, {})
        )
        identity_groups = merge(
          try(local.production_teams[team_key].identity_groups, {}),
          try(local.environment_teams[team_key].identity_groups, {})
        )
      }
    )
  }

  env = module.workspace.env

  environment = module.workspace.environment

  environment_folder_id = local.team_data != null && local.environment_key != null ? try(local.team_data.environments[local.environment_key], null) : null

  environment_key = local.environment != null ? title(local.environment) : null

  environment_root_folder_id = local.team_data != null ? try(local.team_data.environment_root_folder_id, null) : null

  environment_teams = local.environment != "production" && length(local.foundation_workspaces) > 0 ? merge([
    for workspace_name, workspace_data in data.terraform_remote_state.foundation_environment :
    try(workspace_data.outputs.teams, {})
  ]...) : {}

  foundation_environment_bucket = var.foundation_environment_state_bucket != null ? var.foundation_environment_state_bucket : (local.env != null ? "foundation-state-${local.env}" : null)

  # Environment workspace names mirror the production workspace names supplied by consumers.
  foundation_environment_workspaces = var.foundation_workspaces != null && local.environment != "production" ? toset([
    for workspace_name in var.foundation_workspaces :
    "${trimsuffix(workspace_name, "-main-production")}-main-${local.environment}"
  ]) : toset([])

  foundation_production_bucket = var.foundation_production_state_bucket != null ? var.foundation_production_state_bucket : "foundation-state-prod"

  foundation_workspaces = var.foundation_workspaces != null ? toset(var.foundation_workspaces) : toset([])

  labels = {
    cost-center         = var.cost_center
    data-classification = var.data_classification
    env                 = local.environment
    region              = module.workspace.region
    repository          = var.repository
    team                = var.team
    zone                = module.workspace.zone != null ? "${module.workspace.region}-${module.workspace.zone}" : null
  }

  production_teams = length(local.foundation_workspaces) > 0 ? merge([
    for workspace_name, workspace_data in data.terraform_remote_state.foundation :
    try(workspace_data.outputs.teams, {})
  ]...) : {}

  # Project naming components for downstream consumption
  project_naming = local.team_data != null ? {
    prefix   = var.team
    team_key = var.team
  } : null

  team_data = var.foundation_workspaces != null ? try(local.all_teams[var.team], null) : null
}
