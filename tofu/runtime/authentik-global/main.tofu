# The Cloud SQL Auth Proxy sidecar in the authentik pods connects as this service account through
# Workload Identity. Every regional authentik cluster shares the project's identity pool, namespace
# and chart ServiceAccount, so one account serves them all.

resource "google_project_iam_member" "authentik_cloud_sql_client" {
  member  = local.cloud_sql_member
  project = local.project
  role    = "roles/cloudsql.client"
}

resource "google_service_account" "authentik_cloud_sql" {
  account_id   = "authentik-cloud-sql"
  display_name = "Authentik Cloud SQL Auth Proxy"
  project      = local.project
}

resource "google_service_account_iam_member" "authentik_cloud_sql_workload_identity" {
  member             = local.workload_identity_member
  role               = "roles/iam.workloadIdentityUser"
  service_account_id = google_service_account.authentik_cloud_sql.name
}

resource "google_sql_database" "authentik" {
  lifecycle {
    precondition {
      condition     = local.cloud_sql_instance != null
      error_message = "No Cloud SQL instance matching authentik-* was found in ${local.primary_region}; apply Assembly with the authentik cloud_sql entry first."
    }
  }

  instance = local.cloud_sql_instance.name
  name     = local.database_name
  project  = local.project
}

resource "google_sql_user" "authentik" {
  instance = local.cloud_sql_instance.name
  name     = local.database_user
  password = random_password.authentik_database.result
  project  = local.project
}

# These secrets are generated once and shared by every regional server and worker, so all
# instances form one identity provider with the same signing and session state.

resource "random_password" "authentik_admin" {
  length  = 32
  special = true
}

resource "random_password" "authentik_bootstrap_token" {
  length  = 60
  special = false
}

resource "random_password" "authentik_database" {
  length  = 32
  special = false
}

resource "random_password" "authentik_secret_key" {
  length  = 50
  special = false
}
