# Local Values
# https://opentofu.org/docs/language/values/locals

# The selector is shared by the Deployment and the Service.

locals {
  additional_namespaces = join(",", sort(tolist(var.additional_namespaces)))

  kubernetes_manifest_floor_api_authorization_manifest = {
    apiVersion = "security.istio.io/v1"
    kind       = "AuthorizationPolicy"
    metadata = {
      name      = "floor-api"
      namespace = var.namespace
    }
    spec = {
      action = "DENY"
      rules = [
        {
          from = [
            {
              source = {
                notPrincipals = [var.gateway_principal]
              }
            }
          ]
          to = [
            {
              operation = {
                ports = [tostring(var.service_port)]
              }
            }
          ]
        }
      ]
      selector = {
        matchLabels = local.selector_labels
      }
    }
  }

  # Rolling the pods is the only way a changed token reaches the running process.
  pod_annotations = {
    "checksum/github-token" = var.github_token_checksum
  }

  selector_labels = {
    "app.kubernetes.io/name" = "floor-api"
  }
}
