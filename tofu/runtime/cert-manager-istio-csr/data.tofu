data "terraform_remote_state" "trust" {
  backend = "gcs"
  config = {
    bucket = var.bucket
    prefix = "runtime"
  }
  workspace = local.terraform_remote_state_trust_workspace
}
