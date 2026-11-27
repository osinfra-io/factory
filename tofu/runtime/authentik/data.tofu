data "terraform_remote_state" "global" {
  backend = "gcs"
  config = {
    bucket = var.bucket
    prefix = "runtime"
  }
  workspace = local.terraform_remote_state_global_workspace
}
