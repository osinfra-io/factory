module "opa_gatekeeper_templates" {
  source = "../../modules/kubernetes/opa-gatekeeper/regional/templates"

  for_each = local.instances
}
