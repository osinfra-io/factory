# Output Values
# https://opentofu.org/docs/language/values/outputs

output "embedded_outpost_name" {
  description = "The name of the built-in embedded outpost, used by the root module's import block to bring it under management"
  value       = local.embedded_outpost_name
}

output "outpost_namespace" {
  description = "The namespace of the regional authentik-server that serves the embedded outpost for Istio ext_authz forward-auth"
  value       = var.namespace
}

output "outpost_service_name" {
  description = "The Kubernetes Service name of the regional authentik-server embedded outpost for the Istio ext_authz ExtensionProvider"
  value       = local.outpost_service_name
}

output "outpost_service_port" {
  description = "The Kubernetes Service port of the regional authentik-server embedded outpost for the Istio ext_authz ExtensionProvider"
  value       = local.outpost_service_port
}
