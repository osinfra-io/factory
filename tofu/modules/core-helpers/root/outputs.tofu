# Output Values
# https://opentofu.org/docs/language/values/outputs

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
