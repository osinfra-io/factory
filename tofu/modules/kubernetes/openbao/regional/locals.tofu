# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  # The chart renders `server.affinity` as a template, so it is a string rather than a map.
  affinity = var.anti_affinity_enabled ? local.anti_affinity : ""

  anti_affinity = <<-EOT
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        - labelSelector:
            matchLabels:
              app.kubernetes.io/name: openbao
              app.kubernetes.io/instance: openbao
              component: server
          topologyKey: kubernetes.io/hostname
  EOT


  helm_values = yamlencode({
    global = {
      tlsDisable = var.tls_disable
    }

    injector = {
      enabled = true
    }

    server = {
      affinity = local.affinity

      annotations = var.server_annotations

      auditStorage = {
        enabled = true
      }

      configAnnotation = var.server_config_annotation

      extraEnvironmentVars = var.server_extra_environment_vars

      extraLabels = var.labels

      extraVolumes = var.server_extra_volumes

      ha = {
        enabled  = true
        replicas = var.replicas
        raft     = local.raft_configuration
      }

      resources = {
        limits = {
          cpu    = var.cpu_limits
          memory = var.memory_limits
        }
        requests = {
          cpu    = var.cpu_requests
          memory = var.memory_requests
        }
      }

      service = {
        annotations = var.service_annotations
        type        = var.service_type
      }

      serviceAccount = {
        annotations = var.server_service_account_annotations
        name        = var.server_service_account_name
      }

      updateStrategyType = var.server_update_strategy_type
    }

    ui = {
      enabled = true
    }
  })
  raft_configuration = merge(
    { enabled = true },
    var.raft_configuration == "" ? {} : { config = var.raft_configuration }
  )

  service_name = "openbao"
}
