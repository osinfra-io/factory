locals {
  artifact_registries = {
    for team, config in var.teams : team => coalesce(config.artifact_registry, { github_repository_ids = toset([]), readers = toset([]), writers = toset([]) })
    if config.artifact_registry != null || contains(keys(local.gke_teams), team)
  }

  artifact_registries_output = {
    for team, registry in google_artifact_registry_repository.docker_standard : team => {
      standard = registry.id
      virtual  = google_artifact_registry_repository.docker_virtual[team].id
    }
  }

  cloud_sql_instances = merge({}, [
    for team, config in local.workload_teams : {
      for name, instance in config.cloud_sql : "${team}/${name}" => merge(instance, {
        instance_name = name
        project_id    = module.google_project_workloads[team].id
        team          = team
      })
    }
  ]...)

  dns_domain = {
    non-production = "nonprod.osinfra.io."
    production     = "osinfra.io."
    sandbox        = "sb.osinfra.io."
  }[var.environment]

  dns_records = {
    for record in var.dns_records : "${record.name}:${record.type}" => {
      name    = record.name == "" ? local.dns_domain : "${record.name}.${local.dns_domain}"
      rrdatas = record.rrdatas
      ttl     = record.ttl
      type    = record.type
    }
  }

  dns_writers = merge({}, [
    for team, config in local.gke_teams : {
      for member in config.kubernetes_engine.dns_writers : "${team}/${member}" => { team = team, member = member }
    }
  ]...)

  dns_zone_name = replace(trimsuffix(local.dns_domain, "."), ".", "-")

  foundation_workspace = "foundation-main-${var.environment}"

  github_owner_condition = "assertion.repository_owner_id == ${jsonencode(var.github_repository_owner_id)}"

  github_publishers = { for team, registry in local.artifact_registries : team => registry if length(registry.github_repository_ids) > 0 }

  github_registry_publishers_output = {
    for team, publisher in google_service_account.registry_publishers : team => {
      provider        = google_iam_workload_identity_pool_provider.github[var.environment].name
      service_account = publisher.email
    }
  }

  github_repository_bindings = merge({}, [
    for team, registry in local.github_publishers : {
      for repository in registry.github_repository_ids : "${team}/${repository}" => {
        repository = repository
        team       = team
      }
    }
  ]...)

  github_repository_principals = {
    for key, binding in local.github_repository_bindings :
    key => "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.registry_publishers[var.environment].name}/attribute.repository_id/${binding.repository}"
  }

  github_workload_identity = length(local.github_publishers) == 0 ? {} : local.network_projects

  gke_service_agents = {
    for team in keys(local.gke_teams) :
    team => google_project_service_identity.gke[team].member
  }

  gke_teams = {
    for team, config in local.workload_teams : team => config
    if config.kubernetes_engine != null && length(config.kubernetes_engine.locations) > 0
  }

  google_artifact_registry_repository_docker_remote_lifecycle_enabled = length(local.artifact_registries) > 0





  google_artifact_registry_repository_docker_standard_repository_id_by_instance = {
    for instance_key, instance_value in local.artifact_registries : instance_key => "${instance_key}-standard"
  }

  google_artifact_registry_repository_docker_virtual_repository_id_by_instance = {
    for instance_key, instance_value in local.artifact_registries : instance_key => "${instance_key}-virtual"
  }

  google_network_private_dns_dns_name = "private.${local.dns_domain}"

  google_network_private_dns_name = "private-${local.dns_zone_name}"

  google_network_team_dns_name_by_instance = {
    for instance_key, instance_value in local.team_dns : instance_key => "${instance_key}-${local.dns_zone_name}"
  }

  google_project_iam_custom_role_dns_records_for_each = length(local.dns_writers) == 0 ? {} : local.network_projects

  google_project_iam_custom_role_gke_firewall_for_each = length(local.gke_teams) == 0 ? {} : local.network_projects

  google_project_teams_services_by_instance = {
    for instance_key, instance_value in local.team_projects : instance_key => concat(local.project_services, tolist(instance_value.services))
  }

  google_service_account_registry_publishers_account_id_by_instance = {
    for instance_key, instance_value in local.github_publishers : instance_key => "${instance_key}-publisher"
  }

  google_service_account_registry_publishers_display_name_by_instance = {
    for instance_key, instance_value in local.github_publishers : instance_key => "Factory registry publisher (${instance_key})"
  }

  hub_teams = {
    for team, config in local.gke_teams : team => config
    if team == try(var.gke_fleet_host.team, null)
  }

  network_projects = {
    (var.environment) = trimprefix(local.team_folder_ids[var.host_project_team], "folders/")
  }

  network_services = concat(
    local.project_services,
    ["artifactregistry.googleapis.com", "container.googleapis.com", "dns.googleapis.com", "iamcredentials.googleapis.com", "servicenetworking.googleapis.com", "storage.googleapis.com", "sts.googleapis.com"],
  )

  private_dns = {
    dns_name = module.google_network_private_dns[var.environment].dns_name
    name     = module.google_network_private_dns[var.environment].name
  }

  private_service_ranges = {
    (var.environment) = {
      address       = cidrhost(var.private_service_range, 0)
      prefix_length = tonumber(split("/", var.private_service_range)[1])
    }
  }

  project_administrators = merge({}, [
    for team, config in local.team_projects : {
      for member in config.administrators : "${team}/${member}" => {
        member = member
        team   = team
      }
    }
  ]...)

  project_services = [
    "billingbudgets.googleapis.com",
    "cloudasset.googleapis.com",
    "cloudbilling.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "compute.googleapis.com",
    "iam.googleapis.com",
    "monitoring.googleapis.com",
    "pubsub.googleapis.com",
    "securitycenter.googleapis.com",
    "serviceusage.googleapis.com",
  ]

  public_dns = {
    dns_name     = module.google_network_environment_dns[var.environment].dns_name
    name_servers = module.google_network_environment_dns[var.environment].name_servers
  }

  regional_subnets = {
    for region in local.regions : region => {
      for key, subnet in local.team_subnets : key => merge(subnet, {
        gke_service_agent      = local.gke_service_agents[subnet.team]
        service_project_id     = module.google_project_workloads[subnet.team].id
        service_project_number = module.google_project_workloads[subnet.team].number
      }) if subnet.region == region
    }
  }

  regions = toset([for subnet in values(local.team_subnets) : subnet.region])

  registry_reader_members = merge([
    for team, members in local.registry_readers : {
      for member in members : "${team}:${member}" => {
        member = member
        team   = team
      }
    }
  ]...)

  registry_readers = {
    for team, registry in local.artifact_registries : team => setunion(
      registry.readers,
      try(local.gke_teams[team].kubernetes_engine.registry_pullers, toset([])),
      toset(flatten([
        for member_team, member_config in local.gke_teams :
        tolist(member_config.kubernetes_engine.registry_pullers)
        if contains(keys(local.hub_teams), team) && member_team != team
      ])),
    )
  }

  registry_writer_teams = {
    for team, registry in local.artifact_registries : team => registry
    if length(registry.writers) > 0 || contains(keys(local.github_publishers), team)
  }

  registry_writers = {
    for team, registry in local.registry_writer_teams : team => setunion(
      registry.writers,
      contains(keys(local.github_publishers), team) ? ["serviceAccount:${google_service_account.registry_publishers[team].email}"] : [],
    )
  }

  runtime_project_grants = merge({}, flatten([
    for team, roles in var.runtime_project_access : [
      for role, members in roles : {
        for member in members : jsonencode([team, role, member]) => { team = team, role = role, member = member }
      }
    ]
  ])...)

  shared_vpc = {
    host_project_id = module.google_project_network[var.environment].id
    name            = module.google_network_vpc[var.environment].name
  }

  state_bucket_names = {
    for team, folder_id in local.team_folder_ids : team => "${team}-${trimprefix(folder_id, "folders/")}-state-${module.core_helpers.env}"
  }

  team_dns = {
    for team, config in local.gke_teams : team => "${coalesce(config.kubernetes_engine.dns_subdomain, team)}.${local.dns_domain}"
  }

  team_dns_output = {
    for team, zone in module.google_network_team_dns : team => {
      dns_name = zone.dns_name
      name     = zone.name
    }
  }

  team_folder_ids = {
    for team in keys(var.teams) : team => data.terraform_remote_state.foundation.outputs.teams[team].team_folder_id
  }

  team_project_prefixes = {
    for team in keys(local.team_projects) : team => "${team}-team"
  }

  team_projects = { for team, config in var.teams : team => config.google_project if config.google_project != null }

  team_projects_output = {
    for team, project in module.google_project_teams : team => {
      id     = project.id
      number = project.number
    }
  }

  team_state_output = {
    for team, bucket in module.google_storage_bucket : team => {
      bucket  = bucket.name
      kms_key = google_kms_crypto_key.team_state[team].id
    }
  }

  team_subnets = merge({}, [
    for team, config in local.gke_teams : {
      for location, cluster in config.kubernetes_engine.locations : "${team}-${location}" => {
        enable_gke_hub_host = team == try(var.gke_fleet_host.team, null) && location == try(var.gke_fleet_host.location, null)
        location            = location
        ranges = {
          control_plane = cluster.subnet.master_ipv4_cidr_block
          nodes         = cluster.subnet.ip_cidr_range
          pods          = cluster.subnet.pod_ip_cidr_range
          services      = cluster.subnet.services_ip_cidr_range
        }
        region = substr(location, 0, length(location) - 2)
        team   = team
      }
    }
  ]...)

  workload_folder_ids = {
    for team in setunion(keys(local.workload_teams), keys(local.team_projects)) : team => trimprefix(local.team_folder_ids[team], "folders/")
  }

  workload_project_services = {
    for team, config in local.workload_teams : team => concat(
      local.project_services,
      contains(keys(local.gke_teams), team) ? ["certificatemanager.googleapis.com", "cloudkms.googleapis.com", "container.googleapis.com", "gkehub.googleapis.com", "iamcredentials.googleapis.com", "multiclusterservicediscovery.googleapis.com", "trafficdirector.googleapis.com"] : [],
      contains(keys(local.hub_teams), team) ? ["multiclusteringress.googleapis.com"] : [],
      length(config.cloud_sql) > 0 ? ["servicenetworking.googleapis.com", "sqladmin.googleapis.com"] : [],
    )
  }

  workload_projects_output = {
    for team, project in module.google_project_workloads : team => {
      id     = project.id
      number = project.number
    }
  }

  workload_teams = {
    for team, config in var.teams : team => config.workload_project
    if config.workload_project != null
  }
}
