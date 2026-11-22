# Google Compute Security Policy Resource
# https://search.opentofu.org/provider/hashicorp/google/latest/docs/resources/compute_security_policy

resource "google_compute_security_policy" "shared_ingress" {
  provider = google-beta

  advanced_options_config {
    log_level = "VERBOSE"
  }

  adaptive_protection_config {
    auto_deploy_config {
      confidence_threshold        = 0.5
      expiration_sec              = 7200
      impacted_baseline_threshold = 0.01
      load_threshold              = 0.8
    }

    layer_7_ddos_defense_config {
      enable = true
    }
  }

  name    = local.shared_ingress_policy_name
  project = local.assembly.workload_projects[var.team].id

  rule {
    action      = "deny(403)"
    description = "Deny requests with Host headers outside osinfra.io"

    match {
      expr {
        expression = local.cloud_armor_external_hostname_deny_expression
      }
    }

    preview  = false
    priority = 7000
  }

  dynamic "rule" {
    for_each = local.openbao_cloud_armor_deny_rules

    content {
      action      = "deny(403)"
      description = rule.value.description

      match {
        expr {
          expression = rule.value.expression
        }
      }

      preview  = false
      priority = rule.value.priority
    }
  }

  dynamic "rule" {
    for_each = local.authentik_cloud_armor_allow_rules

    content {
      action      = "allow"
      description = rule.value.description

      match {
        expr {
          expression = rule.value.expression
        }
      }

      preview  = false
      priority = rule.value.priority
    }
  }

  dynamic "rule" {
    for_each = local.cloud_armor_preconfigured_waf_rules

    content {
      action      = rule.value.action
      description = rule.value.description

      match {
        expr {
          expression = local.cloud_armor_waf_rule_expressions[rule.value.name]
        }
      }

      dynamic "preconfigured_waf_config" {
        for_each = length(local.cloud_armor_waf_exclusions_by_rule_set[rule.value.name]) > 0 ? [1] : []

        content {
          dynamic "exclusion" {
            for_each = local.cloud_armor_waf_exclusions_by_rule_set[rule.value.name]

            content {
              target_rule_ids = exclusion.value.target_rule_ids
              target_rule_set = exclusion.value.target_rule_set

              dynamic "request_query_param" {
                for_each = exclusion.value.request_query_param_names

                content {
                  operator = "EQUALS"
                  value    = request_query_param.value
                }
              }
            }
          }
        }
      }

      preview  = rule.value.preview
      priority = rule.value.priority
    }
  }

  rule {
    action      = "throttle"
    description = "Rate limit each source IP to 5000 requests per minute"

    match {
      config {
        src_ip_ranges = ["*"]
      }

      versioned_expr = "SRC_IPS_V1"
    }

    preview  = false
    priority = 30000

    rate_limit_options {
      conform_action = "allow"
      enforce_on_key = "IP"
      exceed_action  = "deny(429)"

      rate_limit_threshold {
        count        = 5000
        interval_sec = 60
      }
    }
  }

  rule {
    action      = "allow"
    description = "Default allow rule"

    match {
      config {
        src_ip_ranges = ["*"]
      }

      versioned_expr = "SRC_IPS_V1"
    }

    priority = 2147483647
  }
}

# Google Compute SSL Policy Resource
# https://search.opentofu.org/provider/hashicorp/google/latest/docs/resources/compute_ssl_policy

resource "google_compute_ssl_policy" "shared_ingress" {
  min_tls_version = "TLS_1_2"
  name            = local.shared_ingress_policy_name
  profile         = "MODERN"
  project         = local.assembly.workload_projects[var.team].id
}
