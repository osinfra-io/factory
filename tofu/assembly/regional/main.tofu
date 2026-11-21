module "core_helpers" {
  source = "../../modules/core-helpers/child"
}

module "google_cloud_sql" {
  source = "../../modules/google/cloud-sql/regional"

  for_each = local.cloud_sql_instances

  database_version = each.value.database_version
  host_project_id  = local.main.shared_vpc.host_project_id
  instance_name    = each.value.instance_name
  machine_tier     = each.value.machine_tier
  network          = local.main.shared_vpc.name
  project          = each.value.project_id
  region           = module.core_helpers.region
}

module "google_network_master_subnets" {
  source = "../../modules/google/network/regional"

  for_each = local.regional_subnets

  ip_cidr_range            = each.value.ranges.control_plane
  name                     = "${each.key}-master"
  network                  = local.main.shared_vpc.name
  private_ip_google_access = true
  project                  = local.main.shared_vpc.host_project_id
}

module "google_network_subnets" {
  source = "../../modules/google/network/regional"

  for_each = local.regional_subnets

  ip_cidr_range            = each.value.ranges.nodes
  name                     = each.key
  network                  = local.main.shared_vpc.name
  private_ip_google_access = true
  project                  = local.main.shared_vpc.host_project_id

  secondary_ip_ranges = [
    {
      ip_cidr_range = each.value.ranges.pods
      range_name    = "k8s-secondary-pods"
    },
    {
      ip_cidr_range = each.value.ranges.services
      range_name    = "k8s-secondary-services"
    },
  ]
}

module "google_network_nat" {
  source = "../../modules/google/network/regional/nat"

  depends_on = [module.google_network_subnets]
  for_each   = length(local.regional_subnets) > 0 ? toset([module.core_helpers.region]) : toset([])

  network = local.main.shared_vpc.name
  project = local.main.shared_vpc.host_project_id
}

resource "google_compute_subnetwork_iam_member" "master" {
  for_each = local.network_users

  member     = each.value.member
  project    = local.main.shared_vpc.host_project_id
  region     = module.core_helpers.region
  role       = "roles/compute.networkUser"
  subnetwork = module.google_network_master_subnets[each.value.cluster].name
}

resource "google_compute_subnetwork_iam_member" "workloads" {
  for_each = local.network_users

  member     = each.value.member
  project    = local.main.shared_vpc.host_project_id
  region     = module.core_helpers.region
  role       = "roles/compute.networkUser"
  subnetwork = module.google_network_subnets[each.value.cluster].name
}

resource "google_dns_record_set" "cloud_sql" {
  for_each = local.cloud_sql_instances

  managed_zone = local.main.private_dns.name
  name         = local.cloud_sql_dns[each.key]
  project      = local.main.shared_vpc.host_project_id
  rrdatas      = [module.google_cloud_sql[each.key].private_ip_address]
  ttl          = 300
  type         = "A"
}
