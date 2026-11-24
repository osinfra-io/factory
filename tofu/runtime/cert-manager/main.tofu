module "cert_manager" {
  source = "../../modules/kubernetes/cert-manager/regional"

  for_each = local.instances
}
