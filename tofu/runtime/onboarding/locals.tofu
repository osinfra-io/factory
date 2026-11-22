locals {
  stage = "onboarding"

  namespaces = {
    authentik = {
      "istio.io/dataplane-mode" = "ambient"
    }
    cert-manager = {}
    gatekeeper-system = {
      "admission.gatekeeper.sh/ignore" = "no-self-managing"
    }
    istio-ingress = {}
    istio-system  = {}
  }
}
