output "gateway_dns" {
  description = "Public hosts served by the Istio gateway and the zones that hold their records"
  value       = local.gateway_dns
}

output "gateway_mci_global_address" {
  description = "The IP address for the Istio Gateway multi-cluster ingress"
  value       = module.istio.gateway_mci_global_address
}

output "gateway_mci_ssl_certificate_names" {
  description = "The names of the SSL certificates to attach to the Istio Gateway multi-cluster ingress"
  value       = module.istio.gateway_mci_ssl_certificate_names
}
