module "istio" {
  source = "../../modules/kubernetes/istio"

  gateway_dns = local.gateway_dns
  project     = local.assembly.workload_projects[var.team].id
}
