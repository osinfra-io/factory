locals {
  # Each zone also answers on a zone-prefixed alias of every gateway host.
  gateway_dns = {
    for host, record in data.terraform_remote_state.global.outputs.gateway_dns :
    "${local.location}.${host}" => record
  }

  stage = "istio"
}
