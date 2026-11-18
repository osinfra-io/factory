# Terraform Remote State - Foundation
# https://opentofu.org/docs/language/state/remote-state-data

data "terraform_remote_state" "foundation" {
  for_each = local.foundation_workspaces

  backend = "gcs"

  config = {
    bucket = "foundation-state-prod"
    prefix = "foundation"
  }

  workspace = each.key
}

data "terraform_remote_state" "foundation_environment" {
  for_each = local.foundation_environment_workspaces

  backend = "gcs"

  config = {
    bucket = local.foundation_environment_bucket
    prefix = "foundation"
  }

  workspace = each.key
}
