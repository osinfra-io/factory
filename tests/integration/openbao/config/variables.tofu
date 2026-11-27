# Input Variables
# https://opentofu.org/docs/language/values/variables

variable "authentik_client_id" {
  description = "Client ID of the local authentik OpenBao provider"
  type        = string
}

variable "authentik_client_secret" {
  description = "Client secret of the local authentik OpenBao provider"
  sensitive   = true
  type        = string
}

variable "authentik_discovery_ca_pem" {
  description = "Local gateway certificate trusted for authentik OIDC discovery"
  sensitive   = true
  type        = string
}

variable "authentik_issuer_url" {
  description = "Provider-specific issuer URL of the local authentik OpenBao provider"
  type        = string
}

variable "openbao_address" {
  description = "Local API address of the OpenBao service"
  type        = string
}

variable "openbao_root_token" {
  description = "Throwaway root token for the local OpenBao fixture"
  sensitive   = true
  type        = string
}
