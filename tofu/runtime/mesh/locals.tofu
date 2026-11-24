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

  peers = toset([for location in var.locations : location if location != local.location])

  stage = "mesh"
}
