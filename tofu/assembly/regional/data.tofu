data "terraform_remote_state" "assembly" {
  backend = "gcs"
  config = {
    bucket = var.bucket
    prefix = "assembly"
  }
  workspace = local.main_workspace

  lifecycle {
    precondition {
      condition     = local.regional_workspace_valid
      error_message = "Use a regional Assembly workspace for us-east1 or us-east4 in Sandbox, Non-Production, or Production."
    }
  }
}
