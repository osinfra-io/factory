output "ca_cert_pem" {
  description = "Shared self-signed CA certificate"
  value       = tls_self_signed_cert.cert_manager_ca.cert_pem
}

output "ca_key_pem" {
  description = "Shared self-signed CA private key"
  sensitive   = true
  value       = tls_private_key.cert_manager_ca.private_key_pem
}
