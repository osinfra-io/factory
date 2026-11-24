module "agentgateway" {
  source = "../../modules/kubernetes/agentgateway/regional"

  for_each = local.instances

  namespace = kubernetes_namespace_v1.agentgateway[each.key].metadata[0].name
}

# Kubernetes Namespace Resource
# https://search.opentofu.org/provider/hashicorp/kubernetes/latest/docs/resources/namespace_v1

resource "kubernetes_namespace_v1" "agentgateway" {
  for_each = local.instances

  metadata {
    labels = {
      "istio.io/dataplane-mode" = "ambient"
    }

    name = "agentgateway"
  }
}
