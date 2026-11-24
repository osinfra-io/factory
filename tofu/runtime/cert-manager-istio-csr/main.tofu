module "cert_manager_istio_csr" {
  source = "../../modules/kubernetes/cert-manager/regional/istio-csr"

  for_each = local.instances

  cluster_prefix                              = local.cluster.team
  tls_self_signed_cert_cert_manager_root_cert = data.terraform_remote_state.trust.outputs.ca_cert_pem
  tls_self_signed_cert_cert_manager_root_key  = data.terraform_remote_state.trust.outputs.ca_key_pem
}
