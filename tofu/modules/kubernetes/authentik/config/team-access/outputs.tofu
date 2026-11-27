# Output Values
# https://opentofu.org/docs/language/values/outputs

output "application_group_members" {
  description = "Exact managed group names and selected environment emails for authentik membership validation."
  value       = local.application_group_members
}

output "application_groups" {
  description = "Stable team/group identifiers consumed by authentik configuration."
  value       = local.application_groups
}
