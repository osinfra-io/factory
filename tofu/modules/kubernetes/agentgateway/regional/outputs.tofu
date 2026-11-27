# Output Values
# https://opentofu.org/docs/language/values/outputs

output "gateway_name" {
  description = "Name of the agentgateway Gateway and proxy service"
  value       = local.gateway_name
}

output "namespace" {
  description = "Namespace containing agentgateway"
  value       = var.namespace
}

output "proxy_service_account_name" {
  description = "Service account used by the agentgateway proxy"
  value       = local.proxy_service_account_name
}

output "service_name" {
  description = "Name of the internal agentgateway proxy service"
  value       = local.gateway_name
}

output "service_port" {
  description = "Port exposed by the internal agentgateway proxy service"
  value       = 80
}
