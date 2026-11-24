module "opa_gatekeeper" {
  source = "../../modules/kubernetes/opa-gatekeeper/regional"

  for_each = local.instances

  artifact_registry = local.cluster.artifact_registry
}
