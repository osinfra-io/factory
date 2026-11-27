# Kubernetes Manifest Resource
# https://search.opentofu.org/provider/hashicorp/kubernetes/latest/docs/resources/manifest

resource "kubernetes_manifest" "block_ingress_constraint_template" {
  manifest = local.kubernetes_manifest_block_ingress_constraint_template_manifest
}

resource "kubernetes_manifest" "protect_gateway_auth_constraint_template" {
  manifest = local.kubernetes_manifest_protect_gateway_auth_constraint_template_manifest
}
