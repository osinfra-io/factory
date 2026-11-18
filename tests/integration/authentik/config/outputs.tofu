# Output Values
# https://opentofu.org/docs/language/values/outputs

output "authentication" {
  description = "Shared authentication configuration exercised by the local fixture"
  value = {
    authentication_stage_policies         = module.authentik_config.authentication_stage_policies
    authentication_stages                 = module.authentik_config.authentication_stages
    brand                                 = module.authentik_config.brand
    built_in_brand_domain                 = module.authentik_config.built_in_brand_domain
    default_authentication_stage_settings = module.authentik_config.default_authentication_stage_settings
    flow                                  = module.authentik_config.flow
    policy_bindings                       = module.authentik_config.policy_bindings
    stage_bindings                        = module.authentik_config.stage_bindings
  }
}

output "openbao_client_id" {
  description = "Local OpenBao OIDC client ID"
  value       = module.authentik_config.openbao_client_id
}

output "openbao_client_secret" {
  description = "Local OpenBao OIDC client secret"
  sensitive   = true
  value       = module.authentik_config.openbao_client_secret
}

output "openbao_issuer_url" {
  description = "Local OpenBao OIDC issuer URL"
  value       = module.authentik_config.openbao_issuer_url
}
