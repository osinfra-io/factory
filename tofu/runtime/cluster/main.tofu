module "google_kubernetes_engine_regional" {
  source = "../../modules/google/kubernetes-engine/regional"

  for_each = local.clusters

  artifact_registry_repository = each.value.artifact_registry_repository
  cluster_prefix               = each.value.team
  enable_deletion_protection   = false
  enable_gateway_api           = true
  enable_gke_hub_host          = each.value.enable_gke_hub_host
  gke_hub_memberships          = local.gke_hub_memberships
  node_pools                   = { default = var.node_pool }
  private_endpoint_subnetwork  = each.value.private_endpoint_subnetwork
  project                      = each.value.project_id
  subnet                       = each.value.subnet
  vpc_host_project_id          = each.value.host_project_id
}
