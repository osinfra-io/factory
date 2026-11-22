# AgentgatewayParameters is a CRD installed by the agentgateway stage, so it needs its own later apply.
# Labels are omitted on purpose: the CRD's embedded pod template metadata is defaulted by the API server,
# which makes kubernetes_manifest fail with an inconsistent result after apply.
module "agentgateway_manifests" {
  source = "../../modules/kubernetes/agentgateway/regional/manifests"

  for_each = local.instances

  namespace = "agentgateway"
  proxy_env = {
    ADMIN_ADDR = "0.0.0.0:15000"
  }
}
