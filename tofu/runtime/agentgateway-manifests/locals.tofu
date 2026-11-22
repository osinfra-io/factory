locals {
  labels = {
    env  = module.core_helpers.environment
    team = local.cluster.team
  }

  stage = "agentgateway-manifests"
}
