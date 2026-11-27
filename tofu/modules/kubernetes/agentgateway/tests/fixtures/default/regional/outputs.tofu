output "gateway_name" {
  description = "agentgateway Gateway name"
  value       = module.agentgateway.gateway_name
}

output "namespace" {
  description = "Namespace containing agentgateway"
  value       = module.agentgateway.namespace
}

output "service_port" {
  description = "agentgateway Service port"
  value       = module.agentgateway.service_port
}
