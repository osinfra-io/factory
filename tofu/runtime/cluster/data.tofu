data "terraform_remote_state" "assembly_regional" {
  backend = "gcs"
  config = {
    bucket = var.bucket
    prefix = "assembly"
  }
  workspace = local.assembly_workspace

  lifecycle {
    precondition {
      condition     = local.workspace_valid
      error_message = "Use a zonal Runtime workspace such as us-east1-b-runtime-sandbox."
    }
  }
}

data "terraform_remote_state" "assembly_member_regions" {
  for_each = local.member_regions

  backend = "gcs"
  config = {
    bucket = var.bucket
    prefix = "assembly"
  }
  workspace = "${each.key}-assembly-${module.core_helpers.environment}"
}
