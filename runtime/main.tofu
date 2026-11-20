module "google_kubernetes_engine_regional" {
  source = "../tofu/modules/google/kubernetes-engine/regional"

  for_each = local.clusters

  cluster_prefix              = each.value.team
  enable_deletion_protection  = false
  enable_gke_hub_host         = each.value.enable_gke_hub_host
  node_pools                  = { default = var.node_pool }
  private_endpoint_subnetwork = each.value.private_endpoint_subnetwork
  project                     = each.value.project_id
  subnet                      = each.value.subnet
  vpc_host_project_id         = each.value.host_project_id
}
