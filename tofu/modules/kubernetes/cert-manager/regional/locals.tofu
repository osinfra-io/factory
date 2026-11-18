# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  helm_values = {
    cainjector = {
      replicaCount = var.cainjector_replicas

      resources = {
        limits = {
          cpu    = var.cainjector_resources_limits_cpu
          memory = var.cainjector_resources_limits_memory
        }

        requests = {
          cpu    = var.cainjector_resources_requests_cpu
          memory = var.cainjector_resources_requests_memory
        }
      }
    }

    replicaCount = var.replicas

    resources = {
      limits = {
        cpu    = var.resources_limits_cpu
        memory = var.resources_limits_memory
      }

      requests = {
        cpu    = var.resources_requests_cpu
        memory = var.resources_requests_memory
      }
    }

    startupapicheck = {
      resources = {
        limits = {
          cpu    = var.startupapicheck_resources_limits_cpu
          memory = var.startupapicheck_resources_limits_memory
        }

        requests = {
          cpu    = var.startupapicheck_resources_requests_cpu
          memory = var.startupapicheck_resources_requests_memory
        }
      }
    }

    webhook = {
      replicaCount = var.webhook_replicas

      resources = {
        limits = {
          cpu    = var.webhook_resources_limits_cpu
          memory = var.webhook_resources_limits_memory
        }

        requests = {
          cpu    = var.webhook_resources_requests_cpu
          memory = var.webhook_resources_requests_memory
        }
      }
    }
  }
}
