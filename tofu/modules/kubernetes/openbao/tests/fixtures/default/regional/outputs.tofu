output "namespace" {
  description = "Namespace containing OpenBao"
  value       = module.openbao.namespace
}

output "service_name" {
  description = "OpenBao Service name"
  value       = module.openbao.service_name
}

output "service_port" {
  description = "OpenBao Service port"
  value       = module.openbao.service_port
}
