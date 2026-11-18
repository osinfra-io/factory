# Authentik Brand
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/data-sources/brand

data "authentik_brand" "built_in" {
  domain = module.authentik_config.built_in_brand_domain
}

data "authentik_stage" "default_authentication" {
  name = module.authentik_config.default_authentication_identification_stage_name
}
