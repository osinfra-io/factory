locals {
  kubernetes_manifest_agentgateway_data_authorization_manifest = {
    apiVersion = "security.istio.io/v1"
    kind       = "AuthorizationPolicy"
    metadata = {
      name      = "agentgateway-data"
      namespace = var.namespace
    }
    spec = {
      action = "DENY"
      rules = [
        {
          from = [
            {
              source = {
                notPrincipals = [var.istio_ingress_principal]
              }
            }
          ]
          to = [
            {
              operation = {
                ports = [tostring(var.data_port)]
              }
            }
          ]
        }
      ]
      selector = {
        matchLabels = {
          "gateway.networking.k8s.io/gateway-name" = var.gateway_name
        }
      }
    }
  }
}
