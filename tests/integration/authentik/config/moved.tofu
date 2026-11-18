# Resource moves
# https://opentofu.org/docs/language/moved/

moved {
  from = module.authentik.authentik_brand.built_in
  to   = module.authentik_config.authentik_brand.built_in
}

moved {
  from = module.authentik.authentik_brand.this
  to   = module.authentik_config.authentik_brand.this
}

moved {
  from = module.authentik.authentik_flow.authentication
  to   = module.authentik_config.authentik_flow.authentication
}

moved {
  from = module.authentik.authentik_flow_stage_binding.authentication_stages
  to   = module.authentik_config.authentik_flow_stage_binding.authentication_stages
}

moved {
  from = module.authentik.authentik_policy_binding.authentication_stage_policies
  to   = module.authentik_config.authentik_policy_binding.authentication_stage_policies
}

moved {
  from = module.authentik_config.authentik_outpost.embedded
  to   = module.authentik_regional_config.authentik_outpost.embedded
}
