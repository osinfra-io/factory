locals {
  agentgateway_hostname_output = "agentgateway.${local.environment_domain}"
  assembly                     = data.terraform_remote_state.assembly.outputs

  # authentik's token-authenticated management API receives generated JSON and uses PUT/DELETE,
  # which trigger false positives in Cloud Armor's protocol and method enforcement rules. There is
  # no scoped WAF exclusion for HTTP method/protocol enforcement, so this remains a full allow rule.
  authentik_cloud_armor_allow_rules = {
    authentik_api = {
      description = "Allow token-authenticated authentik API requests"
      expression  = "has(request.headers['host']) && request.headers['host'].matches(${jsonencode(local.authentik_gateway_hostname_regex)}) && request.path.startsWith('/api/v3/') && has(request.headers['authorization']) && request.headers['authorization'].startsWith('Bearer ')"
      priority    = 9000
    }
  }

  # The Google OAuth flow's "scope" query parameter (e.g. "userinfo.profile") is false-positive
  # matched by the preconfigured LFI WAF rule (owasp-crs-v030301-id930120-lfi). authentik re-wraps
  # the original query string (including "scope") inside its own "query" parameter at every step of
  # the flow (browser callback -> /if/flow/<slug>/ -> /api/v3/flows/executor/<slug>/), including
  # built-in system flows (e.g. default-source-authentication for returning users) whose slugs are
  # not defined by this repo. Excluding just the "scope" and "query" parameter values from the LFI
  # rule's inspection (rather than allowing the whole request past every preconfigured WAF rule)
  # fixes the false positive while still running SQLi/XSS/RCE/etc. checks on this traffic.
  #
  # Google also appends "prompt=none" to the callback, which the preconfigured RCE WAF rule
  # (owasp-crs-v030301-id932115-rce) reads as the Windows "prompt" command once it is wrapped in the
  # "query" parameter. The same exclusion is applied to that rule.
  authentik_cloud_armor_waf_exclusions = [
    {
      request_query_param_names = ["scope", "query"]
      target_rule_ids           = ["owasp-crs-v030301-id930120-lfi"]
      target_rule_set           = "lfi-v33-stable"
    },
    {
      request_query_param_names = ["query"]
      target_rule_ids           = ["owasp-crs-v030301-id932115-rce"]
      target_rule_set           = "rce-v33-stable"
    }
  ]

  authentik_gateway_hostname_regex = format(
    "^%s$",
    join("$|^", [for hostname in local.authentik_gateway_hostnames : replace(hostname, ".", "\\.")])
  )

  # The apex host plus the zone-prefixed alias each Runtime cluster serves.
  authentik_gateway_hostnames = distinct(concat(
    [local.authentik_hostname],
    [for location in var.locations : "${location}.${local.authentik_hostname}"]
  ))

  authentik_hostname = "authentik.${local.environment_domain}"

  cloud_armor_allowed_hostname_regex = "^(?:[a-z0-9-]+\\.)*osinfra\\.io\\.?(?::[0-9]+)?$"

  cloud_armor_external_hostname_deny_expression = "!has(request.headers['host']) || !request.headers['host'].lower().matches(${jsonencode(local.cloud_armor_allowed_hostname_regex)})"

  cloud_armor_method_enforcement_exception_expression = join(" || ", [
    for scope in local.cloud_armor_method_enforcement_exceptions :
    "(has(request.headers['host']) && request.headers['host'].matches(${jsonencode(scope.hostname_regex != "" ? scope.hostname_regex : format("^%s$", replace(scope.hostname, ".", "\\.")))}) && request.path.startsWith(${jsonencode(scope.path_prefix)}) && request.method.matches(${jsonencode(join("|", [for method in sort(tolist(scope.methods)) : "^${method}$"]))}))"
  ])

  cloud_armor_method_enforcement_exceptions = [
    {
      hostname       = ""
      hostname_regex = local.authentik_gateway_hostname_regex
      methods        = ["DELETE", "PATCH", "PUT"]
      path_prefix    = "/api/v3/"
    },
    {
      hostname       = ""
      hostname_regex = local.openbao_gateway_hostname_regex
      methods        = ["DELETE", "LIST", "PATCH", "PUT"]
      path_prefix    = "/v1/"
    },
  ]

  cloud_armor_preconfigured_waf_rules = [
    {
      action      = "deny(403)"
      description = "OWASP: SQL injection"
      name        = "sqli-v33-stable"
      preview     = false
      priority    = 10000
      sensitivity = 1
    },
    {
      action      = "deny(403)"
      description = "OWASP: Cross-site scripting"
      name        = "xss-v33-stable"
      preview     = false
      priority    = 10010
      sensitivity = 1
    },
    {
      action      = "deny(403)"
      description = "OWASP: Local file inclusion"
      name        = "lfi-v33-stable"
      preview     = false
      priority    = 10020
      sensitivity = 1
    },
    {
      action      = "deny(403)"
      description = "OWASP: Remote file inclusion"
      name        = "rfi-v33-stable"
      preview     = false
      priority    = 10030
      sensitivity = 1
    },
    {
      action      = "deny(403)"
      description = "OWASP: Remote code execution"
      name        = "rce-v33-stable"
      preview     = false
      priority    = 10040
      sensitivity = 1
    },
    {
      action      = "deny(403)"
      description = "OWASP: Method enforcement"
      name        = "methodenforcement-v33-stable"
      preview     = false
      priority    = 10050
      sensitivity = 1
    },
    {
      action      = "deny(403)"
      description = "OWASP: Scanner detection"
      name        = "scannerdetection-v33-stable"
      preview     = false
      priority    = 10060
      sensitivity = 1
    },
    {
      action      = "deny(403)"
      description = "OWASP: Protocol attack"
      name        = "protocolattack-v33-stable"
      preview     = false
      priority    = 10070
      sensitivity = 1
    },
    {
      action      = "deny(403)"
      description = "OWASP: PHP injection attack"
      name        = "php-v33-stable"
      preview     = false
      priority    = 10080
      sensitivity = 1
    },
    {
      action      = "deny(403)"
      description = "OWASP: Session fixation"
      name        = "sessionfixation-v33-stable"
      preview     = false
      priority    = 10090
      sensitivity = 1
    },
    {
      action      = "deny(403)"
      description = "OWASP: Java attack"
      name        = "java-v33-stable"
      preview     = false
      priority    = 10100
      sensitivity = 1
    },
    {
      action      = "deny(403)"
      description = "OWASP: NodeJS attack"
      name        = "nodejs-v33-stable"
      preview     = false
      priority    = 10110
      sensitivity = 1
    },
    {
      action      = "deny(403)"
      description = "Log4j vulnerability"
      name        = "cve-canary"
      preview     = false
      priority    = 10120
      sensitivity = 1
    },
    {
      action      = "deny(403)"
      description = "JSON-based SQL injection bypass vulnerability"
      name        = "json-sqli-canary"
      preview     = false
      priority    = 10130
      sensitivity = 1
    },
  ]

  cloud_armor_waf_config_instances = {
    for name, exclusions in local.cloud_armor_waf_exclusions_by_rule_set :
    name => length(exclusions) > 0 ? [1] : []
  }

  cloud_armor_waf_exclusions_by_rule_set = {
    for rule in local.cloud_armor_preconfigured_waf_rules : rule.name => [
      for exclusion in local.authentik_cloud_armor_waf_exclusions : exclusion
      if exclusion.target_rule_set == rule.name
    ]
  }

  cloud_armor_waf_rule_expressions = {
    for rule in local.cloud_armor_preconfigured_waf_rules : rule.name =>
    rule.name == "methodenforcement-v33-stable" && length(local.cloud_armor_method_enforcement_exceptions) > 0 ?
    "evaluatePreconfiguredWaf('${rule.name}', {'sensitivity': ${rule.sensitivity}}) && !(${local.cloud_armor_method_enforcement_exception_expression})" :
    rule.name == "rce-v33-stable" ?
    "(evaluatePreconfiguredWaf('${rule.name}', {'sensitivity': ${rule.sensitivity}}) && !(${local.openbao_kv_waf_exception_expression})) || evaluatePreconfiguredWaf('${rule.name}', {'sensitivity': ${rule.sensitivity}, 'opt_out_rule_ids': ['owasp-crs-v030301-id932100-rce']})" :
    "evaluatePreconfiguredWaf('${rule.name}', {'sensitivity': ${rule.sensitivity}})"
  }

  # Environment-level hosts are shared by every team, so they live in the environment zone.
  environment_domain = trimsuffix(local.assembly.public_dns.dns_name, ".")

  environment_zone_name = replace(local.environment_domain, ".", "-")

  gateway_dns = {
    (trimsuffix(local.assembly.team_dns[var.team].dns_name, ".")) = {
      managed_zone = local.assembly.team_dns[var.team].name
      project      = local.assembly.shared_vpc.host_project_id
    }
    "agentgateway.${local.environment_domain}" = {
      managed_zone = local.environment_zone_name
      project      = local.assembly.shared_vpc.host_project_id
    }
    "authentik.${local.environment_domain}" = {
      managed_zone = local.environment_zone_name
      project      = local.assembly.shared_vpc.host_project_id
    }
  }

  google_dns_record_set_openbao_mci_name = "${local.openbao_hostname}."

  openbao_cloud_armor_deny_rules = {
    openbao_metrics = {
      description = "Deny external requests to OpenBao metrics"
      expression  = "request.path.urlDecode().lower().startsWith('/v1/sys/metrics')"
      priority    = 8000
    }
  }

  # The apex and the regional hosts all front openbao, and automation targets one regional instance.
  openbao_gateway_hostname_regex = "^(?:[a-z0-9-]+\\.)?${replace(local.openbao_hostname, ".", "\\.")}$"

  openbao_hostname = "openbao.${local.environment_domain}"

  openbao_kms_member = "serviceAccount:${google_service_account.openbao_kms.email}"

  # Seal settings the regional openbao stage renders into the gcpckms seal stanza.
  openbao_kms_seal = {
    crypto_key = google_kms_crypto_key.openbao_unseal.name
    key_ring   = google_kms_key_ring.openbao_unseal.name
    project    = google_kms_key_ring.openbao_unseal.project
    region     = google_kms_key_ring.openbao_unseal.location
  }

  # KV secret values can legitimately contain shell commands that trigger RCE signature 932100.
  # Exempt only that signature for KV writes; OpenBao still validates the token and enforces ACLs.
  openbao_kv_waf_exception_expression = "has(request.headers['host']) && request.headers['host'].matches(${jsonencode(local.openbao_gateway_hostname_regex)}) && request.path.startsWith('/v1/kv2/data/') && request.method.matches('^POST$|^PUT$') && has(request.headers['x-vault-token']) && request.headers['x-vault-token'] != ''"

  openbao_workload_identity_member = "serviceAccount:${local.assembly.workload_projects[var.team].id}.svc.id.goog[openbao/openbao]"

  shared_ingress_policy_name = "shared-ingress"

  team_hostname_output = trimsuffix(local.assembly.team_dns[var.team].dns_name, ".")

  terraform_remote_state_assembly_workspace = "assembly-main-${coalesce(module.core_helpers.environment, "unsupported")}"
}
