output "cloud_sql_connection_name" {
  description = "Connection name (project:region:instance) of the authentik Cloud SQL instance"
  value       = local.cloud_sql_instance.connection_name
}

output "cloud_sql_service_account_email" {
  description = "Google service account the Cloud SQL Auth Proxy impersonates through Workload Identity"
  value       = google_service_account.authentik_cloud_sql.email
}

output "database_name" {
  description = "Name of the authentik database"
  value       = google_sql_database.authentik.name
}

output "database_user" {
  description = "Name of the authentik database user"
  value       = google_sql_user.authentik.name
}

output "secret_env" {
  description = "Shared authentik secret key and bootstrap and database credentials"
  sensitive   = true
  value       = local.secret_env
}
