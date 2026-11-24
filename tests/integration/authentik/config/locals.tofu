# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  application_groups = {
    for key, group in module.team_access.application_groups : key => merge(group, {
      members = var.revoke_application_access ? [] : group.members
    })
  }

  browser_group_policy_bindings = {
    agentgateway = {
      groups      = ["factory: agentgateway Admins"]
      host        = "https://agentgateway.localhost"
      icon        = "https://docs.osinfra.io/img/authentik/applications/agentgateway.svg"
      launch_url  = "https://agentgateway.localhost/ui/"
      name        = "agentgateway"
      policy_name = "agentgateway-browser-access"
    }
    development = {
      groups      = ["all"]
      host        = "https://dev.localhost"
      icon        = "https://docs.osinfra.io/img/authentik/applications/istio.svg"
      launch_url  = "https://dev.localhost/istio-test/auth"
      name        = "Istio"
      policy_name = "local-development-browser-access"
    }
    floor = {
      groups      = ["all"]
      hidden      = true
      host        = "https://floor.localhost"
      name        = "floor"
      policy_name = "floor-browser-access"
    }
    kagent = {
      groups      = ["factory: kagent Admins"]
      host        = "https://kagent.localhost"
      icon        = "https://docs.osinfra.io/img/authentik/applications/kagent.svg"
      launch_url  = "https://kagent.localhost/"
      name        = "kagent"
      policy_name = "kagent-browser-access"
    }
  }

  superuser_group_keys = ["factory/authentik-admins"]

  team_access_teams = {
    for team_key, team in var.teams : team_key => {
      authentik_groups = {
        for key, group in team.authentik_groups : key => merge(group, {
          members = merge(group.members, var.local_test_user_email == null ? {} : {
            (var.environment) = [var.local_test_user_email]
          })
        })
      }
    }
  }
}
