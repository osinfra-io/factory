output "application_groups" {
  description = "Managed application groups"
  value       = module.test.application_groups
}

output "browser_group_policy_binding_count" {
  description = "Number of per-host authentik browser policy bindings created by the fixture"
  value       = local.browser_group_policy_binding_count_output
}

output "default_authentication_stage_managed" {
  description = "Whether the fixture keeps the shared authentication stage managed"
  value       = module.test.default_authentication_stage_managed
}

output "google_authentication_user_write_stages" {
  description = "Existing-user updates during Google sign-in"
  value       = module.test.google_authentication_user_write_stages
}

output "google_oauth_source_enabled" {
  description = "Whether the fixture created the optional Google authentik source"
  value       = module.test.google_oauth_source_enabled
}

output "pending_application_members" {
  description = "Members awaiting verified Google enrollment"
  value       = module.test.pending_application_members
}

output "preserved_authentication_source" {
  description = "Whether the fixture preserved its pre-existing authentication source"
  value       = local.preserved_authentication_source_output
}
