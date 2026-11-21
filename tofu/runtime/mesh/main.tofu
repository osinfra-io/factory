# Kubernetes Secret Resource
# https://search.opentofu.org/provider/hashicorp/kubernetes/latest/docs/resources/secret_v1

# A remote secret lets istiod discover endpoints in a peer cluster. Istio watches secrets with
# the istio/multiCluster label; the data key is the peer's cluster name.
resource "kubernetes_secret_v1" "remote_secret" {
  for_each = var.runtime_enabled ? local.peers : toset([])

  data = {
    (local.cluster_names[each.key]) = local.kubeconfigs[each.key]
  }

  metadata {
    annotations = {
      "networking.istio.io/cluster" = local.cluster_names[each.key]
    }

    labels = {
      "istio/multiCluster" = "true"
    }

    name      = "istio-remote-secret-${local.cluster_names[each.key]}"
    namespace = "istio-system"
  }
}
