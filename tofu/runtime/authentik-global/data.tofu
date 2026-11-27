# The Cloud SQL instance is created by Assembly; discover it in the workload project.
data "google_sql_database_instances" "authentik" {
  project = local.project
}

data "terraform_remote_state" "assembly" {
  backend = "gcs"
  config = {
    bucket = var.bucket
    prefix = "assembly"
  }
  workspace = local.terraform_remote_state_assembly_workspace
}
