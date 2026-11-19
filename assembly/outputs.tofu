output "artifact_registries" {
  description = "Standard push and virtual pull repositories by team"
  value = {
    for team, registry in google_artifact_registry_repository.docker_standard : team => {
      standard = registry.id
      virtual  = google_artifact_registry_repository.docker_virtual[team].id
    }
  }
}

output "cloud_sql_instances" {
  description = "Team-requested Cloud SQL instances and their workload projects"
  value       = local.cloud_sql_instances
}

output "github_registry_publishers" {
  description = "Federated registry publishing service accounts and identity provider"
  value = {
    for team, publisher in google_service_account.registry_publishers : team => {
      provider        = google_iam_workload_identity_pool_provider.github[var.environment].name
      service_account = publisher.email
    }
  }
}

output "private_dns" {
  description = "Private DNS zone for services in the Shared VPC"
  value       = local.private_dns
}

output "public_dns" {
  description = "Sandbox public DNS zone and nameservers for the separate parent delegation"
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
  description = "Public DNS zones delegated to Sandbox teams"
  value = {
    for team, zone in module.google_network_team_dns : team => {
      dns_name = zone.dns_name
      name     = zone.name
    }
  }
}

output "team_folder_ids" {
  description = "Team folder IDs read from the current environment's Foundation workspace"
  value       = local.team_folder_ids
}

output "team_projects" {
  description = "Team-managed project IDs and numbers"
  value = {
    for team, project in module.google_project_teams : team => {
      id     = project.id
      number = project.number
    }
  }
}

output "team_state" {
  description = "Versioned GCS buckets and encryption keys for team-owned state"
  value = {
    for team, bucket in module.google_storage_bucket : team => {
      bucket  = bucket.name
      kms_key = google_kms_crypto_key.team_state[team].id
    }
  }
}

output "workload_projects" {
  description = "Platform-managed workload project IDs and numbers"
  value = {
    for team, project in module.google_project_workloads : team => {
      id     = project.id
      number = project.number
    }
  }
}
