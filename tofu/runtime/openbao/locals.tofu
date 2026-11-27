locals {
  # The shared hostname fronts only the fleet's config cluster, because zonal OpenBao instances have independent Raft data.
  config_instances = local.location == "us-east1-b" ? local.instances : toset([])

  global = data.terraform_remote_state.global.outputs

  google_compute_global_address_openbao_ingress_name = "openbao-${local.location}"

  google_dns_record_set_openbao_zonal_name = "${local.zonal_hostname}."

  kubernetes_manifest_openbao_mcs_manifest_by_instance = {
    for instance_key, instance_value in local.config_instances : instance_key => {
      apiVersion = "networking.gke.io/v1"
      kind       = "MultiClusterService"
      metadata = {
        annotations = {
          "cloud.google.com/backend-config" = jsonencode({ "default" = kubernetes_manifest.openbao_backendconfig[instance_key].manifest.metadata.name })
          "cloud.google.com/neg"            = jsonencode({ "ingress" = true })
          "networking.gke.io/app-protocols" = jsonencode({ "https" = "HTTPS" })
        }
        name      = "openbao-mcs"
        namespace = kubernetes_namespace_v1.openbao[instance_key].metadata[0].name
      }
      spec = {
        clusters = local.multi_cluster_service_clusters
        template = {
          spec = {
            ports = [
              {
                name       = "https"
                port       = 8200
                protocol   = "TCP"
                targetPort = 8200
              }
            ]
            selector = {
              "app.kubernetes.io/instance" = "openbao"
              "app.kubernetes.io/name"     = "openbao"
              component                    = "server"
            }
          }
        }
      }
    }
  }

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

  terraform_remote_state_global_workspace = "istio-global-${coalesce(module.core_helpers.environment, "unsupported")}"

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
