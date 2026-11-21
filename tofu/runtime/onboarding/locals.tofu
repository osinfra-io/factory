locals {
  stage = "onboarding"

  namespaces = {
    authentik    = {}
    cert-manager = {}
    gatekeeper-system = {
      "admission.gatekeeper.sh/ignore" = "no-self-managing"
    }
    istio-ingress = {}
    istio-system  = {}
  }
}
