locals {
  artifact_registries = {
    for key, network in local.clusters : key => try(
      format("%s-docker.pkg.dev/%s/%s", local.registry_parts[key].location, local.registry_parts[key].project, local.registry_parts[key].repository),
      null
    )
  }

  assembly = data.terraform_remote_state.assembly_regional.outputs

  assembly_workspace = "${coalesce(module.core_helpers.region, "unsupported")}-assembly-${coalesce(module.core_helpers.environment, "unsupported")}"

  clusters = {
    for key, network in local.assembly.runtime_networks : key => network
    if var.runtime_enabled && network.location == "${module.core_helpers.region}-${module.core_helpers.zone}"
  }

  gke_hub_memberships = {
    for key, network in merge([for region, state in data.terraform_remote_state.assembly_member_regions : state.outputs.runtime_networks]...) : key => {
      cluster_id = "projects/${network.project_id}/locations/${network.region}/clusters/${key}"
    }
    if var.runtime_enabled && network.region != module.core_helpers.region && contains(var.locations, network.location)
  }

  member_regions = toset([
    for region in toset([for location in var.locations : substr(location, 0, length(location) - 2)]) : region
    if region != module.core_helpers.region && anytrue([for network in local.assembly.runtime_networks : network.enable_gke_hub_host && network.location == "${module.core_helpers.region}-${module.core_helpers.zone}"])
  ])

  registry_parts = {
    for key, network in local.clusters : key => try(
      regex("^projects/(?P<project>[^/]+)/locations/(?P<location>[^/]+)/repositories/(?P<repository>[^/]+)$", network.artifact_registry_repository),
      null
    )
  }

  workspace_valid = can(regex("^us-east[14]-[a-f]-runtime-(sandbox|non-production|production)$", terraform.workspace))
}
