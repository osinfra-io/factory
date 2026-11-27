locals {
  kubernetes_deployment_v1_istio_test_container_image = "${local.registry}:${var.image_version}"

  kubernetes_service_v1_istio_test_zonal_metadata_name = "istio-test-${local.location}"
  labels = {
    app = "istio-test"
  }

  # The namespace is created by onboarding so the gateway routes can reference it before this workload exists.
  namespace = "${local.cluster.team}-istio-test"

  registry = "${local.cluster.artifact_registry}/istio-test"

  stage = "istio-test"
}
