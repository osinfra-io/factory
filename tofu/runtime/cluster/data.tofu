data "terraform_remote_state" "assembly_member_regions" {
  for_each = local.member_regions

  backend = "gcs"
  config = {
    bucket = var.bucket
    prefix = "assembly"
  }
  workspace = local.terraform_remote_state_assembly_member_regions_workspace_by_instance[each.key]
}

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
