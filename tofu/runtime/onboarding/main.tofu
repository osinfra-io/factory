# Platform namespaces that other stages install into. Namespaces that carry
# their own workloads (agentgateway, openbao) are created by their modules.

resource "kubernetes_namespace_v1" "this" {
  for_each = local.kubernetes_namespace_v1_this_for_each

  # topology.istio.io/network on istio-system is owned by the Istio stage.
  lifecycle {
    ignore_changes = [metadata[0].labels["topology.istio.io/network"]]
  }

  metadata {
    labels = each.value
    name   = each.key
  }
}
