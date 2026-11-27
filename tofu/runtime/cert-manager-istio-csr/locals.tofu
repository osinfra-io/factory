locals {
  stage = "cert-manager-istio-csr"

  terraform_remote_state_trust_workspace = "trust-${coalesce(module.core_helpers.environment, "unsupported")}"
}
