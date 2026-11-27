locals {
  # Cluster name Istio knows each cluster by: <team>-<region>-<zone>-<environment>.
  cluster_names = {
    for location in local.peers :
    location => "${local.cluster.team}-${location}-${module.core_helpers.env}"
  }

  kubeconfigs = {
    for location in local.peers :
    location => yamlencode({
      apiVersion = "v1"
      kind       = "Config"

      clusters = [{
        name = local.cluster_names[location]
        cluster = {
          certificate-authority-data = values(data.terraform_remote_state.peer_cluster[location].outputs.clusters)[0].ca_certificate
          server                     = "https://${values(data.terraform_remote_state.peer_cluster[location].outputs.clusters)[0].endpoint}"
        }
      }]

      contexts = [{
        name = local.cluster_names[location]
        context = {
          cluster = local.cluster_names[location]
          user    = local.cluster_names[location]
        }
      }]

      current-context = local.cluster_names[location]

      users = [{
        name = local.cluster_names[location]
        user = {
          token = data.terraform_remote_state.peer_istio[location].outputs.reader_token
        }
      }]
    })
  }

  kubernetes_secret_v1_remote_secret_for_each = var.runtime_enabled ? local.peers : toset([])

  kubernetes_secret_v1_remote_secret_metadata_name_by_instance = {
    for instance_key, instance_value in var.runtime_enabled ? local.peers : toset([]) : instance_key => "istio-remote-secret-${local.cluster_names[instance_key]}"
  }

  peers = toset([for location in var.locations : location if location != local.location])

  stage = "mesh"

  terraform_remote_state_peer_cluster_workspace_by_instance = {
    for instance_key, instance_value in local.peers : instance_key => "${instance_key}-runtime-${module.core_helpers.environment}"
  }

  terraform_remote_state_peer_istio_workspace_by_instance = {
    for instance_key, instance_value in local.peers : instance_key => "${instance_key}-istio-${module.core_helpers.environment}"
  }
}
