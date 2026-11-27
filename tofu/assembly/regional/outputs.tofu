output "cloud_sql_instances" {
  description = "Private DNS names and instance connection references for regional Cloud SQL"
  value       = local.cloud_sql_instances_output
}

output "runtime_networks" {
  description = "Regional Shared VPC, workload project, and subnet references consumed by Runtime"
  value       = local.runtime_networks
}
