locals {
  # The shared hostname fronts only the fleet's config cluster, because zonal OpenBao instances have independent Raft data.
  config_instances = local.location == "us-east1-b" ? local.instances : toset([])

  global = data.terraform_remote_state.global.outputs

  labels = {
    env  = module.core_helpers.environment
    team = local.cluster.team
  }

  multi_cluster_service_clusters = [
    {
      link = "us-east1/${local.cluster.team}-us-east1-b"
    }
  ]

  project = local.cluster.project_id

  raft_configuration = <<-EOT
    ui = true

    listener "tcp" {
      address = "[::]:8200"
      cluster_address = "[::]:8201"
      tls_cert_file = "/openbao/userconfig/openbao-tls/tls.crt"
      tls_key_file = "/openbao/userconfig/openbao-tls/tls.key"

      telemetry {
        unauthenticated_metrics_access = true
      }
    }

    seal "gcpckms" {
      crypto_key = "${local.global.openbao_kms_seal.crypto_key}"
      key_ring   = "${local.global.openbao_kms_seal.key_ring}"
      project    = "${local.global.openbao_kms_seal.project}"
      region     = "${local.global.openbao_kms_seal.region}"
    }

    storage "raft" {
      path = "/openbao/data"
    }

    service_registration "kubernetes" {}

    telemetry {
      disable_hostname          = true
      prometheus_retention_time = "24h"
    }
  EOT

  server_extra_environment_vars = {
    BAO_CACERT = "/openbao/userconfig/openbao-tls/ca.crt"
  }

  server_extra_volumes = [
    {
      name = "openbao-tls"
      type = "secret"
    }
  ]

  server_service_account_annotations = {
    "iam.gke.io/gcp-service-account" = local.global.openbao_kms_service_account_email
  }

  service_annotations = {
    "cloud.google.com/app-protocols"  = jsonencode({ https = "HTTPS" })
    "cloud.google.com/backend-config" = jsonencode({ default = "openbao-backend" })
    "cloud.google.com/neg"            = jsonencode({ ingress = true })
  }

  stage = "openbao"

  # SANs for the pod certificate: the external hostnames, every in-cluster name clients and Raft peers
  # use, and loopback for the in-pod bao CLI and probes.
  tls_dns_names = [
    local.global.openbao_hostname,
    local.zonal_hostname,
    "*.openbao-internal",
    "*.openbao-internal.openbao.svc.cluster.local",
    "openbao",
    "openbao-active",
    "openbao-active.openbao.svc.cluster.local",
    "openbao.openbao",
    "openbao.openbao.svc",
    "openbao.openbao.svc.cluster.local",
  ]

  # Each cluster also gets a direct GKE Ingress endpoint, named with its zone prefix.
  zonal_hostname = "${local.location}.${local.global.openbao_hostname}"
}
