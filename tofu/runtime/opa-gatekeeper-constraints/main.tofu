module "opa_gatekeeper_constraints" {
  source = "../../modules/kubernetes/opa-gatekeeper/regional/constraints"

  for_each = local.instances
}
