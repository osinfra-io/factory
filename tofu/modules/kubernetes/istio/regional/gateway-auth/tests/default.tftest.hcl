# Test
# https://opentofu.org/docs/cli/commands/test

run "browser_policy_matches_host_port" {
  command = plan

  variables {
    policies = {
      agentgateway = {
        host = "agentgateway.localhost"
        path = "/"
      }
    }
  }

  assert {
    condition = (
      contains(local.custom_authorization_policy_manifests.agentgateway.spec.rules[0].to[0].operation.hosts, "agentgateway.localhost") &&
      contains(local.custom_authorization_policy_manifests.agentgateway.spec.rules[0].to[0].operation.hosts, "agentgateway.localhost:*")
    )
    error_message = "Browser policies must match requests with and without an explicit host port."
  }
}
