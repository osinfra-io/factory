locals {
  # Each zone also answers on a zone-prefixed alias of every gateway host.
  gateway_dns = {
    for host, record in data.terraform_remote_state.global.outputs.gateway_dns :
    "${local.location}.${host}" => record
  }

  # authentik's database is shared, but its servers stay cluster-local so the outpost ext_authz call
  # never waits on an authentik server in another region. The external load balancer handles failover.
  mesh_config_service_settings = [
    {
      hosts = ["*.authentik.svc.cluster.local"]

      settings = {
        clusterLocal = true
      }
    }
  ]

  # Fleet membership links of every cluster that backs the gateway's MultiClusterService.
  multi_cluster_service_clusters = [
    for location in var.locations : {
      link = "${regex("^(us-[a-z0-9]+)-[a-z]$", location)[0]}/${local.cluster.team}-${location}"
    }
  ]

  stage = "istio"
}
