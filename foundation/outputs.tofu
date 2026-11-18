# Output Values
# https://opentofu.org/docs/language/values/outputs

output "environment_root_folder_id" {
  description = "The existing folder ID for the current environment"
  value       = var.google_environment_root_folder_id
}

output "teams" {
  description = "The Factory team folder and environment metadata"
  value       = local.teams_output
}
