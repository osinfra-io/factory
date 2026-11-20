locals {
  assembly = data.terraform_remote_state.assembly_regional.outputs

  assembly_workspace = "${coalesce(module.core_helpers.region, "unsupported")}-assembly-${coalesce(module.core_helpers.environment, "unsupported")}"

  clusters = {
    for key, network in local.assembly.runtime_networks : key => network
    if network.location == "${module.core_helpers.region}-${module.core_helpers.zone}"
  }

  workspace_valid = can(regex("^us-east[14]-[a-f]-runtime-(sandbox|non-production|production)$", terraform.workspace))
}
