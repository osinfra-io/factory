output "clusters" {
  description = "Clusters created by this workspace"
  value = {
    for key, cluster in module.google_kubernetes_engine_regional : key => {
      artifact_registry = local.artifact_registries[key]
      ca_certificate    = cluster.container_cluster_ca_certificate
      endpoint          = cluster.container_cluster_endpoint
      name              = cluster.container_cluster_name
      project_id        = local.clusters[key].project_id
      team              = local.clusters[key].team
    }
  }
}
