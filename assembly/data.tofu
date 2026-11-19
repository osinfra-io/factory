data "google_storage_project_service_account" "state" {
  depends_on = [module.google_project_network]
  for_each   = length(local.state_buckets) == 0 ? {} : local.network_projects

  project = module.google_project_network[each.key].id
}

data "terraform_remote_state" "foundation" {
  backend = "gcs"
  config = {
    bucket = var.bucket
    prefix = var.prefix
  }
  workspace = local.foundation_workspace

  lifecycle {
    precondition {
      condition     = terraform.workspace == "assembly-main-sandbox"
      error_message = "Use the assembly-main-sandbox workspace for Sandbox Assembly."
    }
  }
}
