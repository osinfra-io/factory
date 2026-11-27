output "artifact_registries" {
  description = "Standard push and virtual pull repositories by team"
  value       = local.artifact_registries_output
}

output "cloud_sql_instances" {
  description = "Team-requested Cloud SQL instances and their workload projects"
  value       = local.cloud_sql_instances
}

output "github_registry_publishers" {
  description = "Federated registry publishing service accounts and identity provider"
  value       = local.github_registry_publishers_output
}

output "private_dns" {
  description = "Private DNS zone for services in the Shared VPC"
  value       = local.private_dns
}

output "public_dns" {
  description = "Environment public DNS zone and nameservers for the separate parent delegation"
  value       = local.public_dns
}

output "regional_subnets" {
  description = "Requested cluster network allocations and service projects grouped by region"
  value       = local.regional_subnets
}

output "shared_vpc" {
  description = "Name and host project of the environment Shared VPC"
  value       = local.shared_vpc
}

output "team_dns" {
  description = "Public DNS zones delegated to teams"
  value       = local.team_dns_output
}

output "team_folder_ids" {
  description = "Team folder IDs read from the current environment's Foundation workspace"
  value       = local.team_folder_ids
}

output "team_projects" {
  description = "Team-managed project IDs and numbers"
  value       = local.team_projects_output
}

output "team_state" {
  description = "Versioned GCS buckets and encryption keys for team-owned state"
  value       = local.team_state_output
}

output "workload_projects" {
  description = "Platform-managed workload project IDs and numbers"
  value       = local.workload_projects_output
}
