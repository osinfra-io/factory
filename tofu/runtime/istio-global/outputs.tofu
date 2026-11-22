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

output "openbao_hostname" {
  description = "Shared public hostname of the OpenBao multi-cluster ingress"
  value       = local.openbao_hostname
}

output "openbao_kms_seal" {
  description = "Cloud KMS settings for the OpenBao auto-unseal gcpckms seal"
  value       = local.openbao_kms_seal
}

output "openbao_kms_service_account_email" {
  description = "Google service account the OpenBao pods impersonate to use the auto-unseal key"
  value       = google_service_account.openbao_kms.email
}

output "openbao_mci_global_address" {
  description = "The IP address for the OpenBao multi-cluster ingress"
  value       = google_compute_global_address.openbao_mci.address
}

output "openbao_mci_ssl_certificate_name" {
  description = "The name of the SSL certificate for the OpenBao multi-cluster ingress"
  value       = google_compute_managed_ssl_certificate.openbao_mci.name
}

output "openbao_public_dns_zone_name" {
  description = "Managed zone holding the OpenBao DNS records"
  value       = local.environment_zone_name
}

output "shared_ingress_policy_name" {
  description = "Name of the Cloud Armor and SSL policy shared by GKE ingresses"
  value       = local.shared_ingress_policy_name
}

output "shared_vpc_host_project_id" {
  description = "Project that hosts the shared VPC and the public DNS zones"
  value       = local.assembly.shared_vpc.host_project_id
}
