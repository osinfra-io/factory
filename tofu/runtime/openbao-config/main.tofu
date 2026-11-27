resource "vault_identity_group" "team" {
  for_each = local.openbao_groups

  name     = each.value.group_name
  policies = [vault_policy.team[each.key].name]
  type     = "external"
}

resource "vault_identity_group_alias" "team" {
  for_each = local.openbao_groups

  canonical_id   = vault_identity_group.team[each.key].id
  mount_accessor = vault_jwt_auth_backend.oidc.accessor
  name           = each.value.group_name
}

resource "vault_jwt_auth_backend" "oidc" {
  default_role       = "default"
  oidc_client_id     = local.authentik_config.openbao_client_id
  oidc_client_secret = local.authentik_config.openbao_client_secret
  oidc_discovery_url = local.authentik_config.openbao_issuer_url
  path               = "oidc"

  tune {
    listing_visibility = "unauth"
  }

  type = "oidc"
}

resource "vault_jwt_auth_backend_role" "oidc" {
  allowed_redirect_uris = local.vault_jwt_auth_backend_role_oidc_allowed_redirect_uris
  backend               = vault_jwt_auth_backend.oidc.path
  bound_audiences       = [local.authentik_config.openbao_client_id]
  groups_claim          = "groups"
  oidc_scopes           = ["email", "groups", "profile"]
  role_name             = "default"
  role_type             = "oidc"
  token_max_ttl         = 3600
  token_policies        = ["default"]
  token_ttl             = 3600
  user_claim            = "sub"
}

resource "vault_kv_secret_v2" "team_readme" {
  for_each = local.team_readme_content

  data_json = local.vault_kv_secret_v2_team_readme_data_json_by_instance[each.key]
  mount     = vault_mount.team_kv2.path
  name      = local.vault_kv_secret_v2_team_readme_name_by_instance[each.key]
}

resource "vault_mount" "team_kv2" {
  options = {
    version = "2"
  }

  path = "kv2"
  type = "kv"
}

resource "vault_policy" "team" {
  depends_on = [vault_mount.team_kv2]
  for_each   = local.team_policy_documents

  name   = local.vault_policy_team_name_by_instance[each.key]
  policy = each.value
}
