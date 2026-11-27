locals {
  assembly = data.terraform_remote_state.assembly.outputs

  cloud_sql_instance = one([
    for instance in data.google_sql_database_instances.authentik.instances :
    instance
    if instance.region == local.primary_region && startswith(instance.name, "authentik-")
  ])

  cloud_sql_member = "serviceAccount:${google_service_account.authentik_cloud_sql.email}"

  database_name = "authentik"

  database_user = "authentik"

  kubernetes_namespace = "authentik"

  kubernetes_service_account = "authentik"

  # Every authentik instance points at the single Cloud SQL primary.
  primary_region = "us-east1"

  project = local.assembly.workload_projects[var.team].id

  secret_env = {
    AUTHENTIK_BOOTSTRAP_PASSWORD   = random_password.authentik_admin.result
    AUTHENTIK_BOOTSTRAP_TOKEN      = random_password.authentik_bootstrap_token.result
    AUTHENTIK_POSTGRESQL__PASSWORD = random_password.authentik_database.result
    AUTHENTIK_SECRET_KEY           = random_password.authentik_secret_key.result
  }

  terraform_remote_state_assembly_workspace = "assembly-main-${coalesce(module.core_helpers.environment, "unsupported")}"

  workload_identity_member = "serviceAccount:${local.project}.svc.id.goog[${local.kubernetes_namespace}/${local.kubernetes_service_account}]"
}
