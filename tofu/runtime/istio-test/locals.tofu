locals {
  labels = {
    app = "istio-test"
  }

  # The namespace is created by onboarding so the gateway routes can reference it before this workload exists.
  namespace = "${local.cluster.team}-istio-test"

  registry = "${local.cluster.artifact_registry}/istio-test"

  stage = "istio-test"
}
