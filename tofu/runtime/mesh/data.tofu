data "terraform_remote_state" "peer_cluster" {
  for_each = local.peers

  backend = "gcs"
  config = {
    bucket = var.bucket
    prefix = "runtime"
  }
  workspace = "${each.key}-runtime-${module.core_helpers.environment}"
}

data "terraform_remote_state" "peer_istio" {
  for_each = local.peers

  backend = "gcs"
  config = {
    bucket = var.bucket
    prefix = "runtime"
  }
  workspace = "${each.key}-istio-${module.core_helpers.environment}"
}
