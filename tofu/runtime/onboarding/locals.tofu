locals {
  stage = "onboarding"

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
}
