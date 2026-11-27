data "terraform_remote_state" "assembly" {
  backend = "gcs"
  config = {
    bucket = var.bucket
    prefix = "assembly"
  }
  workspace = local.terraform_remote_state_assembly_workspace
}
