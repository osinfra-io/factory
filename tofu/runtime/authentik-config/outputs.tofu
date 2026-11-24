output "issuer_url" {
  description = "authentik OIDC issuer URL for the gateway application"
  value       = module.authentik_config.issuer_url
}

output "jwks_uri" {
  description = "authentik OIDC JWKS URI for the gateway application"
  value       = module.authentik_config.jwks_uri
}

output "openbao_client_id" {
  description = "OAuth2 client ID for OpenBao"
  value       = module.authentik_config.openbao_client_id
}

output "openbao_client_secret" {
  description = "OAuth2 client secret for OpenBao"
  sensitive   = true
  value       = module.authentik_config.openbao_client_secret
}

output "openbao_issuer_url" {
  description = "Provider-specific authentik OIDC issuer URL for OpenBao"
  value       = module.authentik_config.openbao_issuer_url
}

output "outpost_namespace" {
  description = "Namespace of the embedded outpost that serves Istio ext_authz forward-auth"
  value       = module.authentik_regional_config.outpost_namespace
}

output "outpost_service_name" {
  description = "Service name of the embedded outpost for the Istio ext_authz extension provider"
  value       = module.authentik_regional_config.outpost_service_name
}

output "outpost_service_port" {
  description = "Service port of the embedded outpost for the Istio ext_authz extension provider"
  value       = module.authentik_regional_config.outpost_service_port
}

output "pending_application_members" {
  description = "Declared application members awaiting a verified Google sign-in"
  sensitive   = true
  value       = module.authentik_config.pending_application_members
}
