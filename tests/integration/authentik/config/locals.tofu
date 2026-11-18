# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  authentik_group_defaults = {
    openbao-secret-admins = {
      description = "Manage secrets and versions within the %s team prefix"
      label       = "OpenBao Secret Admins"
    }
    openbao-secret-readers = {
      description = "Read and list secrets within the %s team prefix"
      label       = "OpenBao Secret Readers"
    }
    openbao-secret-writers = {
      description = "Create and update secrets within the %s team prefix"
      label       = "OpenBao Secret Writers"
    }
  }

  application_groups = {
    for key, group in module.team_access.application_groups : key => merge(group, {
      members = var.revoke_application_access ? [] : group.members
    })
  }

  team_access_teams = {
    for team_key, team in var.teams : team_key => {
      authentik_groups = {
        for key, group in team.authentik_groups : key => {
          description = group.description != null ? group.description : try(format(local.authentik_group_defaults[key].description, team_key), null)
          label       = group.label != null ? group.label : try(local.authentik_group_defaults[key].label, null)
          members = merge(group.members, {
            sandbox = var.local_test_user_email == null ? group.members.sandbox : [var.local_test_user_email]
          })
          name = group.name != null ? group.name : "${team_key}: ${group.label != null ? group.label : try(local.authentik_group_defaults[key].label, key)}"
        }
      }
    }
  }
}
