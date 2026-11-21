module "gateway_auth" {
  source = "../../modules/kubernetes/istio/regional/gateway-auth"
}

module "istio" {
  source = "../../modules/kubernetes/istio/regional"

  for_each = local.instances

  artifact_registry                           = local.cluster.artifact_registry
  cluster_prefix                              = local.cluster.team
  cni_cpu_requests                            = var.resources.cni_cpu_requests
  cni_memory_requests                         = var.resources.cni_memory_requests
  east_west_gateway_cpu_limits                = var.resources.east_west_gateway_cpu_limits
  east_west_gateway_cpu_requests              = var.resources.east_west_gateway_cpu_requests
  east_west_gateway_memory_limits             = var.resources.east_west_gateway_memory_limits
  east_west_gateway_memory_requests           = var.resources.east_west_gateway_memory_requests
  mesh_config_extension_providers             = [module.gateway_auth.extension_provider]
  pilot_autoscale_max                         = var.resources.pilot_autoscale_max
  pilot_cpu_limits                            = var.resources.pilot_cpu_limits
  pilot_cpu_requests                          = var.resources.pilot_cpu_requests
  pilot_memory_limits                         = var.resources.pilot_memory_limits
  pilot_memory_requests                       = var.resources.pilot_memory_requests
  project                                     = local.cluster.project_id
  tls_self_signed_cert_cert_manager_root_cert = data.terraform_remote_state.trust.outputs.ca_cert_pem
  tls_self_signed_cert_cert_manager_root_key  = data.terraform_remote_state.trust.outputs.ca_key_pem
  ztunnel_cpu_requests                        = var.resources.ztunnel_cpu_requests
  ztunnel_memory_requests                     = var.resources.ztunnel_memory_requests
}

# Kubernetes Secret Resource
# https://search.opentofu.org/provider/hashicorp/kubernetes/latest/docs/resources/secret_v1

# Peer clusters read this cluster's API through the istio-reader service account, the same
# credential istioctl create-remote-secret uses. The mesh stage turns it into a remote secret.
resource "kubernetes_secret_v1" "istio_reader" {
  depends_on = [
    module.istio
  ]

  for_each = local.instances

  metadata {
    annotations = {
      "kubernetes.io/service-account.name" = "istio-reader-service-account"
    }

    name      = "istio-reader-service-account-token"
    namespace = "istio-system"
  }

  type = "kubernetes.io/service-account-token"

  wait_for_service_account_token = true
}
