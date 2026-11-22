locals {
  assembly = data.terraform_remote_state.assembly.outputs

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
}
