locals {
  cloud_sql_dns = {
    for key, instance in local.cloud_sql_instances :
    key => "${instance.instance_name}.${module.core_helpers.region}.sql.${instance.team}.${local.main.private_dns.dns_name}"
  }

  cloud_sql_instances = {
    for key, instance in local.main.cloud_sql_instances : key => instance
    if contains(instance.regions, module.core_helpers.region)
  }

  cloud_sql_instances_output = {
    for key, instance in module.google_cloud_sql : key => {
      host               = google_dns_record_set.cloud_sql[key].name
      instance           = instance.instance
      private_ip_address = instance.private_ip_address
    }
  }

  google_network_master_subnets_name_by_instance = {
    for instance_key, instance_value in local.regional_subnets : instance_key => "${instance_key}-master"
  }

  google_network_nat_for_each = length(local.regional_subnets) > 0 ? toset([module.core_helpers.region]) : toset([])

  main = data.terraform_remote_state.assembly.outputs

  main_workspace = "assembly-main-${coalesce(module.core_helpers.environment, "unsupported")}"

  network_users = merge({}, [
    for key, subnet in local.regional_subnets : {
      for agent, member in {
        cloud-services = "serviceAccount:${subnet.service_project_number}@cloudservices.gserviceaccount.com"
        gke            = subnet.gke_service_agent
        } : "${key}/${agent}" => {
        cluster = key
        member  = member
      }
    }
  ]...)

  regional_subnets = lookup(local.main.regional_subnets, module.core_helpers.region, {})

  regional_workspace_valid = can(regex("^us-east[14]-assembly-(sandbox|non-production|production)$", terraform.workspace))

  runtime_networks = {
    for key, subnet in local.regional_subnets : key => {
      artifact_registry_repository = try(local.main.artifact_registries[subnet.team].virtual, null)
      enable_gke_hub_host          = subnet.enable_gke_hub_host
      host_project_id              = local.main.shared_vpc.host_project_id
      location                     = subnet.location
      network                      = local.main.shared_vpc.name
      private_endpoint_subnetwork  = module.google_network_master_subnets[key].name
      project_id                   = subnet.service_project_id
      region                       = module.core_helpers.region
      subnet                       = module.google_network_subnets[key].name
      team                         = subnet.team
    }
  }
}
