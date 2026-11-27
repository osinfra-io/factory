data "terraform_remote_state" "peer_cluster" {
  for_each = local.peers

  backend = "gcs"
  config = {
    bucket = var.bucket
    prefix = "runtime"
  }
  workspace = local.terraform_remote_state_peer_cluster_workspace_by_instance[each.key]
}

data "terraform_remote_state" "peer_istio" {
  for_each = local.peers

  backend = "gcs"
  config = {
    bucket = var.bucket
    prefix = "runtime"
  }
  workspace = local.terraform_remote_state_peer_istio_workspace_by_instance[each.key]
}
