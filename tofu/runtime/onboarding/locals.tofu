locals {
  kubernetes_namespace_v1_this_for_each = var.runtime_enabled ? local.namespaces : {}

  namespaces = {
    authentik = {
      "istio.io/dataplane-mode" = "ambient"
    }
    cert-manager = {}
    factory-istio-test = {
      "istio.io/dataplane-mode" = "ambient"
    }
    gatekeeper-system = {
      "admission.gatekeeper.sh/ignore" = "no-self-managing"
    }
    istio-ingress = {}
    istio-system  = {}
  }

  stage = "onboarding"
}
