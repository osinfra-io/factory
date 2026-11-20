output "clusters" {
  description = "Clusters created by this workspace"
  value = {
    for key, cluster in module.google_kubernetes_engine_regional : key => {
      endpoint = cluster.container_cluster_endpoint
      name     = cluster.container_cluster_name
    }
  }
}
