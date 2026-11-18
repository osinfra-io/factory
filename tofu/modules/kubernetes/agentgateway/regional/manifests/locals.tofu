# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  # Must match local.gateway_name in //regional; the two modules are separate OpenTofu roots
  # and cannot reference each other's state, so the stable proxy naming convention is
  # duplicated rather than computed.
  gateway_name = "agentgateway-proxy"

  # Empty objects inside the CRD's schemaless deployment spec break kubernetes_manifest's state conversion.
  proxy_deployment_spec = merge({
    replicas = var.proxy_replicas
    }, length(var.labels) == 0 ? {} : {
    template = {
      metadata = {
        labels = var.labels
      }
    }
  })

  proxy_parameters_spec = merge({
    deployment = {
      spec = local.proxy_deployment_spec
    }
    logging = {
      format = "json"
    }
    resources = {
      limits = {
        cpu    = var.proxy_cpu_limits
        memory = var.proxy_memory_limits
      }
      requests = {
        cpu    = var.proxy_cpu_requests
        memory = var.proxy_memory_requests
      }
    }
    service = {
      spec = {
        type = "ClusterIP"
      }
    }
    }, var.proxy_env == {} ? {} : {
    env = [for name, value in var.proxy_env : { name = name, value = value }]
  })
}
