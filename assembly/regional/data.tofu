data "terraform_remote_state" "assembly" {
  backend = "gcs"
  config = {
    bucket = var.bucket
    prefix = "assembly"
  }
  workspace = local.main_workspace

  lifecycle {
    precondition {
      condition     = module.core_helpers.environment == "sandbox" && contains(["us-east1", "us-east4"], coalesce(module.core_helpers.region, "unsupported"))
      error_message = "Use a regional Sandbox Assembly workspace, such as us-east1-assembly-sandbox."
    }
  }
}
