output "api_endpoint" {
  description = "agent substrate API endpoint"
  value       = module.agent_substrate.api_endpoint
}

output "namespace" {
  description = "Namespace containing agent substrate"
  value       = module.agent_substrate.namespace
}
