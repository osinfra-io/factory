module "core_helpers" {
  source = "../modules/core-helpers/child"
}

module "google_network_environment_dns" {
  source = "../modules/google/network/dns"

  depends_on = [module.google_project_network]
  for_each   = local.network_projects

  dns_name   = local.dns_domain
  name       = local.dns_zone_name
  project    = module.google_project_network[each.key].id
  visibility = "public"
}

module "google_network_private_dns" {
  source = "../modules/google/network/dns"

  for_each = local.network_projects

  dns_name                           = "private.${local.dns_domain}"
  name                               = "private-${local.dns_zone_name}"
  private_visibility_config_networks = [module.google_network_vpc[each.key].self_link]
  project                            = module.google_project_network[each.key].id
  visibility                         = "private"
}

module "google_network_team_dns" {
  source = "../modules/google/network/dns"

  depends_on = [module.google_project_network]
  for_each   = local.team_dns

  dns_name   = each.value
  name       = "${each.key}-${local.dns_zone_name}"
  project    = module.google_project_network[var.environment].id
  visibility = "public"
}

module "google_network_vpc" {
  source = "../modules/google/network"

  depends_on = [module.google_project_network]
  for_each   = local.network_projects

  name       = "standard-shared"
  project    = module.google_project_network[each.key].id
  shared_vpc = true
}

module "google_project_network" {
  source = "../modules/google/project"

  for_each = local.network_projects
  providers = {
    google.budget = google.budget
  }

  billing_account       = var.billing_account_id
  folder_id             = each.value
  monthly_budget_amount = var.monthly_project_budgets.host
  prefix                = var.host_project_team
  services              = local.network_services
}

module "google_project_teams" {
  source = "../modules/google/project"

  depends_on = [module.google_project_network]
  for_each   = local.team_projects
  providers = {
    google.budget = google.budget
  }

  billing_account = var.billing_account_id
  cis_2_2_logging_sink = {
    project_id = module.google_project_network[var.environment].id
  }
  folder_id             = local.workload_folder_ids[each.key]
  monthly_budget_amount = var.monthly_project_budgets.team
  prefix                = local.team_project_prefixes[each.key]
  services              = concat(local.project_services, tolist(each.value.services))
}

module "google_project_workloads" {
  source = "../modules/google/project"

  depends_on = [module.google_project_network]
  for_each   = local.workload_teams
  providers = {
    google.budget = google.budget
  }

  billing_account = var.billing_account_id
  cis_2_2_logging_sink = {
    project_id = module.google_project_network[var.environment].id
  }
  folder_id             = local.workload_folder_ids[each.key]
  monthly_budget_amount = var.monthly_project_budgets.workload
  prefix                = each.key
  services              = local.workload_project_services[each.key]
}

module "google_storage_bucket" {
  source = "../modules/google/storage-bucket"

  depends_on = [google_kms_crypto_key_iam_member.state_storage]
  for_each   = local.state_bucket_names

  default_kms_key_name = google_kms_crypto_key.team_state[each.key].id
  location             = "US"
  name                 = each.value
  project              = module.google_project_network[var.environment].id
}

resource "google_artifact_registry_repository" "docker_remote" {
  depends_on = [module.google_project_network]

  lifecycle {
    enabled = length(local.artifact_registries) > 0
  }

  description   = "Docker Hub upstream"
  format        = "DOCKER"
  location      = "us"
  mode          = "REMOTE_REPOSITORY"
  project       = module.google_project_network[var.environment].id
  repository_id = "docker-remote"

  remote_repository_config {
    description = "Docker Hub"

    docker_repository {
      public_repository = "DOCKER_HUB"
    }
  }
}

resource "google_artifact_registry_repository" "docker_standard" {
  depends_on = [module.google_project_network]
  for_each   = local.artifact_registries

  format        = "DOCKER"
  location      = "us"
  project       = module.google_project_network[var.environment].id
  repository_id = "${each.key}-standard"
}

resource "google_artifact_registry_repository" "docker_virtual" {
  for_each = local.artifact_registries

  format        = "DOCKER"
  location      = "us"
  mode          = "VIRTUAL_REPOSITORY"
  project       = module.google_project_network[var.environment].id
  repository_id = "${each.key}-virtual"

  virtual_repository_config {
    upstream_policies {
      id         = each.key
      priority   = 20
      repository = google_artifact_registry_repository.docker_standard[each.key].id
    }

    upstream_policies {
      id         = "docker"
      priority   = 10
      repository = google_artifact_registry_repository.docker_remote.id
    }
  }
}

resource "google_artifact_registry_repository_iam_binding" "readers" {
  for_each = { for team, members in local.registry_readers : team => members if length(members) > 0 }

  location   = google_artifact_registry_repository.docker_virtual[each.key].location
  members    = each.value
  project    = google_artifact_registry_repository.docker_virtual[each.key].project
  repository = google_artifact_registry_repository.docker_virtual[each.key].name
  role       = "roles/artifactregistry.reader"
}

resource "google_artifact_registry_repository_iam_binding" "writers" {
  for_each = local.registry_writer_teams

  location   = google_artifact_registry_repository.docker_standard[each.key].location
  members    = local.registry_writers[each.key]
  project    = google_artifact_registry_repository.docker_standard[each.key].project
  repository = google_artifact_registry_repository.docker_standard[each.key].name
  role       = "roles/artifactregistry.writer"
}

resource "google_compute_global_address" "private_services" {
  for_each = local.private_service_ranges

  address       = each.value.address
  address_type  = "INTERNAL"
  name          = "service-network-peering-range"
  network       = module.google_network_vpc[each.key].self_link
  prefix_length = each.value.prefix_length
  project       = module.google_project_network[each.key].id
  purpose       = "VPC_PEERING"
}

resource "google_compute_shared_vpc_service_project" "external" {
  depends_on = [module.google_network_vpc]
  for_each   = var.external_service_projects

  host_project    = module.google_project_network[var.environment].id
  service_project = each.key
}

resource "google_compute_shared_vpc_service_project" "workloads" {
  depends_on = [module.google_network_vpc, module.google_project_workloads]
  for_each   = local.workload_teams

  host_project    = module.google_project_network[var.environment].id
  service_project = module.google_project_workloads[each.key].id
}

resource "google_dns_managed_zone_iam_member" "team_writers" {
  for_each = local.dns_writers

  managed_zone = module.google_network_team_dns[each.value.team].name
  member       = each.value.member
  project      = module.google_project_network[var.environment].id
  role         = google_project_iam_custom_role.dns_records[var.environment].name
}

resource "google_dns_record_set" "records" {
  for_each = local.dns_records

  managed_zone = module.google_network_environment_dns[var.environment].name
  name         = each.value.name
  project      = module.google_project_network[var.environment].id
  rrdatas      = each.value.rrdatas
  ttl          = each.value.ttl
  type         = each.value.type
}

resource "google_dns_record_set" "team_delegations" {
  for_each = module.google_network_team_dns

  managed_zone = module.google_network_environment_dns[var.environment].name
  name         = each.value.dns_name
  project      = module.google_project_network[var.environment].id
  rrdatas      = each.value.name_servers
  ttl          = 300
  type         = "NS"
}

resource "google_iam_workload_identity_pool" "registry_publishers" {
  depends_on = [module.google_project_network]
  for_each   = local.github_workload_identity

  display_name              = "GitHub registry publishing"
  project                   = module.google_project_network[each.key].id
  workload_identity_pool_id = "github-registry-publishers"
}

resource "google_iam_workload_identity_pool_provider" "github" {
  for_each = local.github_workload_identity

  attribute_condition = local.github_owner_condition
  attribute_mapping = {
    "attribute.repository_id" = "assertion.repository_id"
    "google.subject"          = "assertion.sub"
  }
  display_name = "GitHub Actions OIDC"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  project                            = module.google_project_network[each.key].id
  workload_identity_pool_id          = google_iam_workload_identity_pool.registry_publishers[each.key].workload_identity_pool_id
  workload_identity_pool_provider_id = "github"
}

resource "google_kms_crypto_key" "team_state" {
  for_each = local.state_bucket_names

  lifecycle {
    prevent_destroy = true
  }

  key_ring        = google_kms_key_ring.team_state[var.environment].id
  name            = each.key
  rotation_period = "7776000s"
}

resource "google_kms_crypto_key_iam_member" "state_storage" {
  for_each = local.state_bucket_names

  crypto_key_id = google_kms_crypto_key.team_state[each.key].id
  member        = data.google_storage_project_service_account.state[var.environment].member
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
}

resource "google_kms_key_ring" "team_state" {
  depends_on = [module.google_project_network]
  for_each   = local.network_projects

  lifecycle {
    prevent_destroy = true
  }

  location = "us"
  name     = "team-state"
  project  = module.google_project_network[each.key].id
}

resource "google_project_iam_custom_role" "dns_records" {
  for_each = length(local.dns_writers) == 0 ? {} : local.network_projects

  permissions = [
    "dns.changes.create",
    "dns.changes.get",
    "dns.changes.list",
    "dns.managedZones.get",
    "dns.resourceRecordSets.create",
    "dns.resourceRecordSets.delete",
    "dns.resourceRecordSets.get",
    "dns.resourceRecordSets.list",
    "dns.resourceRecordSets.update",
  ]
  project = module.google_project_network[each.key].id
  role_id = "teamDnsRecords"
  title   = "Team DNS record management"
}

resource "google_project_iam_custom_role" "gke_firewall" {
  for_each = length(local.gke_teams) == 0 ? {} : local.network_projects

  permissions = [
    "compute.firewalls.create",
    "compute.firewalls.delete",
    "compute.firewalls.get",
    "compute.firewalls.list",
    "compute.firewalls.update",
    "compute.networks.updatePolicy",
  ]
  project = module.google_project_network[each.key].id
  role_id = "gkeHostFirewallManagement"
  title   = "GKE Shared VPC firewall management"
}

resource "google_project_iam_member" "gke_firewall" {
  depends_on = [google_compute_shared_vpc_service_project.workloads]
  for_each   = local.gke_teams

  member  = local.gke_service_agents[each.key]
  project = module.google_project_network[var.environment].id
  role    = google_project_iam_custom_role.gke_firewall[var.environment].name
}

resource "google_project_iam_member" "gke_host_agent" {
  depends_on = [google_compute_shared_vpc_service_project.workloads]
  for_each   = local.gke_teams

  member  = local.gke_service_agents[each.key]
  project = module.google_project_network[var.environment].id
  role    = "roles/container.hostServiceAgentUser"
}

resource "google_project_iam_member" "multi_cluster_service_agents" {
  for_each = local.hub_teams

  member  = google_project_service_identity.multi_cluster[each.key].member
  project = module.google_project_network[var.environment].id
  role    = "roles/multiclusterservicediscovery.serviceAgent"
}

resource "google_project_iam_member" "runtime" {
  for_each = local.runtime_project_grants

  member  = each.value.member
  project = module.google_project_workloads[each.value.team].id
  role    = each.value.role
}

resource "google_project_iam_member" "team_project_administrators" {
  for_each = local.project_administrators

  member  = each.value.member
  project = module.google_project_teams[each.value.team].id
  role    = "roles/editor"
}

resource "google_project_service_identity" "gke" {
  depends_on = [module.google_project_workloads]
  for_each   = local.gke_teams
  provider   = google-beta

  project = module.google_project_workloads[each.key].id
  service = "container.googleapis.com"
}

resource "google_project_service_identity" "multi_cluster" {
  depends_on = [module.google_project_workloads]
  for_each   = local.hub_teams
  provider   = google-beta

  project = module.google_project_workloads[each.key].id
  service = "multiclusterservicediscovery.googleapis.com"
}

resource "google_service_account" "registry_publishers" {
  depends_on = [module.google_project_network]
  for_each   = local.github_publishers

  account_id   = "${each.key}-publisher"
  display_name = "Factory registry publisher (${each.key})"
  project      = module.google_project_network[var.environment].id
}

resource "google_service_account_iam_member" "github_publishers" {
  for_each = local.github_repository_bindings

  member             = local.github_repository_principals[each.key]
  role               = "roles/iam.workloadIdentityUser"
  service_account_id = google_service_account.registry_publishers[each.value.team].name
}

resource "google_service_networking_connection" "private_services" {
  for_each = local.private_service_ranges

  network                 = module.google_network_vpc[each.key].self_link
  reserved_peering_ranges = [google_compute_global_address.private_services[each.key].name]
  service                 = "servicenetworking.googleapis.com"
}
