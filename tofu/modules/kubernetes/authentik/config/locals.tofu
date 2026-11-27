# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  all_group_name = "all"

  application_group_attributes = {
    for key, group in var.application_groups : key => jsonencode({
      description = group.description
    })
  }

  application_group_names = {
    for key, group in var.application_groups : group.name => key
  }

  application_group_users = {
    for key, group in var.application_groups : key => [
      for email in group.members : local.google_user_ids_by_email[email]
      if contains(keys(local.google_user_ids_by_email), email)
    ]
  }

  application_groups_enabled = local.google_oauth_enabled && length(var.application_groups) > 0



  application_groups_requested = length(var.application_groups) > 0




  authentication_stage_bindings = local.branding_enabled ? local.authentication_stages : {}

  authentication_stage_policies = {
    for key, stage in local.authentication_stages : key => stage
    if try(stage.policy_name, null) != null
  }

  authentication_stage_policy_bindings = local.branding_enabled ? local.authentication_stage_policies : {}

  authentication_stages = {
    identification = {
      name  = "default-authentication-identification"
      order = 10
    }
    login = {
      name  = "default-authentication-login"
      order = 100
    }
    mfa_validation = {
      name        = "default-authentication-mfa-validation"
      order       = 30
      policy_name = "default-authentication-flow-authenticator-validate-stage"
    }
    password = {
      name        = "default-authentication-password"
      order       = 20
      policy_name = "default-authentication-flow-password-stage"
    }
  }

  # Normalize the base URL so a trailing slash in authentik_url does not produce double slashes in
  # the issuer and JWKS URLs.
  authentik_base_url = trimsuffix(var.authentik_url, "/")

  authentik_group_application_is_superuser_by_instance = {
    for instance_key, instance_value in var.application_groups : instance_key => contains(var.superuser_group_keys, instance_key)
  }

  authentik_provider_proxy_browser_jwt_federation_providers_by_instance = {
    for instance_key, instance_value in var.browser_group_policy_bindings : instance_key => contains(var.cli_oidc_browser_keys, instance_key) ? [authentik_provider_oauth2.cli.id] : []
  }

  brand_attributes = jsonencode({
    settings = {
      theme = {
        base = "dark"
      }
    }
  })

  brand_custom_css = <<-EOT
    :root {
      --ak-c-login--BackgroundColorOverlay: rgba(30, 30, 30, 0.94);
      --ak-c-login__main--BackgroundColor: #232323;
      --ak-c-login__main--Color: #e0e0e0;
      --pf-global--BackgroundColor--100: #1e1e1e;
      --pf-global--BackgroundColor--200: #232323;
      --pf-global--Color--100: #e0e0e0;
      --pf-global--Color--200: #a0a0a0;
      --pf-global--primary-color--100: #ffb400;
      --pf-global--primary-color--200: #e6a200;
      --pf-c-form-control--BackgroundColor: #2b2b2b;
      --pf-c-form-control--after--BorderBottomColor: #484848;
      --pf-c-form-control--focus--after--BorderBottomColor: #606060;
      --pf-c-form-control--hover--after--BorderBottomColor: #606060;
      --pf-c-form-control--m-expanded--after--BorderBottomColor: #606060;
    }

    ::selection {
      background-color: #484848;
      color: #ffffff;
    }

    body:has(ak-flow-executor) {
      --ak-global--background-color: #1e1e1e;
      --ak-global--background-image: none;
    }

    .pf-c-login__main {
      border: 1px solid #353535;
      border-radius: 8px;
    }

    input,
    textarea,
    select {
      background-color: #2b2b2b !important;
      border-color: #484848 !important;
      color: #e0e0e0 !important;
    }

    input:focus,
    input:focus-visible,
    textarea:focus,
    textarea:focus-visible,
    select:focus,
    select:focus-visible {
      background-color: #303030 !important;
      border-color: #606060 !important;
      box-shadow: inset 0 -2px 0 #606060 !important;
      outline-color: #606060 !important;
    }

    input:autofill,
    input:-webkit-autofill,
    input:-webkit-autofill:focus,
    input:-webkit-autofill:hover {
      -webkit-text-fill-color: #e0e0e0 !important;
      box-shadow: inset 0 0 0 1000px #303030 !important;
      caret-color: #e0e0e0;
    }

    .pf-c-button.pf-m-primary {
      background-color: #ffb400;
      color: #1e1e1e;
    }

    .pf-c-button.pf-m-primary:hover {
      background-color: #e6a200;
    }

    #ak-back-home {
      background-color: #ffb400 !important;
      color: #1e1e1e !important;
    }

    #ak-back-home:active,
    #ak-back-home:focus,
    #ak-back-home:hover {
      background-color: #e6a200 !important;
      color: #1e1e1e !important;
    }

    a {
      color: #ffb400;
    }
  EOT

  # authentik strips the final newline; normalize it to avoid perpetual in-place updates.
  brand_custom_css_api = chomp(local.brand_custom_css)

  brand_output = local.branding_enabled ? authentik_brand.this : null

  branding_enabled = var.branding != null



  # Bindings that share a policy name share one policy; validation requires identical requirements.



  browser_access_policies = {
    for name, keys in local.browser_access_policy_keys : name => var.browser_group_policy_bindings[keys[0]]
  }

  browser_access_policy_expressions = {
    for name, binding in local.browser_access_policies : name => <<-EOT
      import json
      from authentik.sources.oauth.models import UserOAuthSourceConnection
      request.debug = True
      requirements = json.loads(${jsonencode(jsonencode({ groups = binding.groups, roles = binding.roles }))})
      user = request.user
      if not user.is_active:
          return False
      names = requirements["groups"] + requirements["roles"]
      if any(": " in name for name in names):
          email = user.attributes.get("osinfra_google_email", "")
          if (
              not isinstance(email, str)
              or not email
              or email != user.email
              or not UserOAuthSourceConnection.objects.filter(user=user, source__slug="google").exists()
          ):
              return False
      memberships = set(user.all_groups().values_list("name", flat=True))
      return all(
          not required or any(name in memberships for name in required)
          for required in (requirements["groups"], requirements["roles"])
      )
    EOT
  }

  browser_access_policy_keys = {
    for key, name in local.browser_access_policy_names : name => key...
  }

  browser_access_policy_names = {
    for key, binding in var.browser_group_policy_bindings : key => coalesce(
      binding.policy_name,
      "${lower(replace(replace(trimprefix(binding.host, "https://"), ".", "-"), "_", "-"))}-browser-access"
    )
  }

  browser_application_names = {
    for key, binding in var.browser_group_policy_bindings : key => coalesce(binding.name, trimprefix(binding.host, "https://"))
  }

  browser_application_slugs = {
    for key, binding in var.browser_group_policy_bindings : key => replace(replace(replace(trimprefix(key, "https://"), ".", "-"), "/", "-"), "_", "-")
  }

  browser_groups = {
    for group in distinct(flatten([
      for binding in values(var.browser_group_policy_bindings) : concat(binding.groups, binding.roles)
      ])) : group => {
      group = group
    }
    if group != local.all_group_name && !contains(keys(local.application_group_names), group)
  }

  # Provider names must be unique, while display names such as "Istio" repeat across hosts.
  browser_provider_names = local.browser_application_slugs

  browser_proxy_property_mapping_ids = concat(
    local.proxy_default_property_mapping_ids,
    local.application_groups_enabled ? [authentik_property_mapping_provider_scope.google_proxy.id] : [],
  )

  built_in_brand_domain = "authentik-default"

  # Name of the built-in default authentication flow's identification stage. Consumers import
  # the pre-existing object into authentik_stage_identification.default_authentication (same
  # pattern as the embedded outpost import), so this module only adds Google to its "sources"
  # list without touching any of its other live settings.
  cli_exchange_client_ids = {
    for key in var.cli_oidc_browser_keys : key => authentik_provider_proxy.browser[key].client_id
  }

  cli_issuer_url = local.cli_oidc_enabled ? "${local.authentik_base_url}/application/o/factory-cli/" : null

  cli_oidc_enabled = length(var.cli_oidc_browser_keys) > 0




  default_authentication_identification_stage_name = "default-authentication-identification"

  default_authentication_source_uuids = local.default_authentication_stage_managed ? nonsensitive(authentik_stage_identification.default_authentication.sources) : []

  default_authentication_stage_managed = var.manage_default_authentication_stage

  default_authentication_stage_sources = distinct(concat(
    var.default_authentication_source_uuids,
    local.google_oauth_enabled ? [authentik_source_oauth.google.uuid] : [],
  ))

  flow_output = local.branding_enabled ? authentik_flow.authentication : null

  google_authentication_flow_id = local.google_oauth_enabled ? authentik_flow.google_authentication.uuid : data.authentik_flow.default_source_authentication.id

  google_authentication_user_write_stages = local.google_oauth_enabled ? [authentik_stage_user_write.google_authentication] : []

  google_group_mapping_expression = <<-EOT
    import json
    memberships = json.loads(${jsonencode(jsonencode(var.application_groups))})
    email = info.get("email", "")
    verification = [info[key] for key in ("email_verified", "verified_email") if key in info]
    if not verification or any(value is not True for value in verification) or not isinstance(email, str) or not email:
        raise ValueError("Application access requires a verified Google email")
    email = email.lower()
    return {
        "email": email,
        "attributes": {"osinfra_google_email": email},
        "groups": sorted({group["name"] for group in memberships.values() if email in group["members"]}),
    }
  EOT

  google_group_matching_mode = length(var.application_groups) > 0 ? "name_link" : "identifier"

  google_identity_mapping_expression = <<-EOT
    import json
    domains = json.loads(${jsonencode(jsonencode(var.google_internal_domains))})
    email = info.get("email", "")
    verification = [info[key] for key in ("email_verified", "verified_email") if key in info]
    internal = (
        bool(verification)
        and all(value is True for value in verification)
        and isinstance(email, str)
        and email.count("@") == 1
        and email.rsplit("@", 1)[1].lower() == info.get("hd")
        and info.get("hd") in domains
    )
    return {"username": email, "type": "internal" if internal else "external"}
  EOT

  google_oauth_enabled = nonsensitive(var.google_oauth_client_id != "" && var.google_oauth_client_secret != "")

  google_proxy_mapping_expression = <<-EOT
    from authentik.sources.oauth.models import UserOAuthSourceConnection
    attributes = dict(request.user.group_attributes(request))
    headers = {
        key: value for key, value in attributes.get("additionalHeaders", {}).items()
        if not key.lower().startswith("x-authentik-")
    }
    email = request.user.attributes.get("osinfra_google_email", "")
    verified = (
        request.user.is_active
        and isinstance(email, str)
        and email != ""
        and email == request.user.email
        and UserOAuthSourceConnection.objects.filter(user=request.user, source__slug="google").exists()
    )
    headers["X-authentik-osinfra-google-email"] = email if verified else ""
    attributes["additionalHeaders"] = headers
    return {
        "ak_proxy": {
            "user_attributes": attributes,
            "is_superuser": request.user.is_superuser,
        }
    }
  EOT

  google_source_property_mapping_ids = concat(
    local.google_oauth_enabled ? [authentik_property_mapping_source_oauth.google_username.id] : [],
    local.application_groups_enabled ? [authentik_property_mapping_source_oauth.google_application_groups.id] : [],
  )

  google_user_ids_by_email = {
    for user in local.google_verified_users : user.email => user.pk
  }

  google_verified_users = local.application_groups_requested ? [
    for user in data.authentik_users.google.users : user
    if try(jsondecode(user.attributes).osinfra_google_email, "") == user.email && user.is_active
  ] : []

  # Per-provider issuer mode: the issuer and JWKS live under the application slug.
  # https://docs.goauthentik.io/add-secure-apps/providers/oauth2
  issuer_url = var.gateway_oidc_enabled ? "${local.authentik_base_url}/application/o/${var.application_slug}/" : null

  jwks_uri = var.gateway_oidc_enabled ? "${local.authentik_base_url}/application/o/${var.application_slug}/jwks/" : null

  openbao_client_id_output = local.openbao_oidc_enabled ? authentik_provider_oauth2.openbao.client_id : null

  openbao_client_secret_output = local.openbao_oidc_enabled ? authentik_provider_oauth2.openbao.client_secret : null

  openbao_issuer_url = local.openbao_oidc_enabled ? "${local.authentik_base_url}/application/o/openbao/" : null

  openbao_oidc_enabled = var.openbao_hostname != null




  openbao_redirect_uris = local.openbao_oidc_enabled ? [
    {
      matching_mode     = "strict"
      redirect_uri_type = "authorization"
      url               = "https://${var.openbao_hostname}/ui/vault/auth/oidc/oidc/callback"
    },
    {
      matching_mode     = "strict"
      redirect_uri_type = "authorization"
      url               = "http://localhost:8250/oidc/callback"
    },
  ] : []

  pending_application_members = {
    for key, group in var.application_groups : key => tolist([
      for email in group.members : email
      if !contains(keys(local.google_user_ids_by_email), email)
    ])
  }

  proxy_default_property_mapping_ids = [
    data.authentik_property_mapping_provider_scope.email.id,
    data.authentik_property_mapping_provider_scope.entitlements.id,
    data.authentik_property_mapping_provider_scope.openid.id,
    data.authentik_property_mapping_provider_scope.profile.id,
    data.authentik_property_mapping_provider_scope.proxy.id,
  ]

  proxy_provider_ids = [for provider in authentik_provider_proxy.browser : provider.id]
}
