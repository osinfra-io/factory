# AgentgatewayParameters is a CRD installed by the agentgateway stage, so it needs its own later apply.
module "agentgateway_manifests" {
  source = "../../modules/kubernetes/agentgateway/regional/manifests"

  for_each = local.instances

  labels    = local.labels
  namespace = "agentgateway"
  proxy_env = {
    ADMIN_ADDR = "0.0.0.0:15000"
  }
}
