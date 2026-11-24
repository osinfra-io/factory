# Output Values
# https://opentofu.org/docs/language/values/outputs

output "env" {
  description = "The short name for the environment for example prod, nonprod, sb"
  value       = local.env
}

output "environment" {
  description = "The environment name for example production, non-production, sandbox"
  value       = local.environment
}

output "environment_folder_id" {
  description = "The folder ID for the current team and environment from Foundation state"
  value       = local.environment_folder_id
}

output "environment_root_folder_id" {
  description = "The folder ID for the environment root from Foundation state"
  value       = local.environment_root_folder_id
}

output "labels" {
  description = "A map of labels to apply to resources"
  value       = local.labels
}

output "project_naming" {
  description = "The project naming configuration from Foundation state. Contains the team name and project ID prefix."
  value       = local.project_naming
}

output "region" {
  description = "The region where resources will be deployed"
  value       = module.workspace.region
}

output "repository" {
  description = "The repository name"
  value       = var.repository
}

output "team" {
  description = "The team name"
  value       = var.team
}

output "teams" {
  description = "All teams data from Foundation workspaces"
  value       = local.all_teams
}

output "zone" {
  description = "The zone where resources will be deployed"
  value       = module.workspace.zone
}
