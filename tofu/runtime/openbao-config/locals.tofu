locals {
  authentik_config = data.terraform_remote_state.authentik_config.outputs

  openbao_address = "https://${var.openbao_zone}.${local.openbao_hostname}"

  openbao_group_keys = [
    "openbao-secret-admins",
    "openbao-secret-readers",
    "openbao-secret-writers",
  ]

  # Group names must match the authentik groups, which authentik-config emits in the groups claim.
  openbao_groups = merge({}, [
    for team_key, team in var.teams : {
      for group_key, group in team.authentik_groups : "${team_key}/${group_key}" => {
        access     = trimprefix(group_key, "openbao-secret-")
        group_name = group.name != null ? group.name : "${team_key}: ${group.label}"
        team_key   = team_key
      }
      if contains(local.openbao_group_keys, group_key)
    }
  ]...)

  openbao_hostname = data.terraform_remote_state.istio_global.outputs.openbao_hostname

  team_readme_content = {
    for team_key in keys(var.teams) : team_key => <<-EOT
      # OpenBao team secrets

      Use the environment's openbao endpoint and sign in with your Google-backed account:

      ```bash
      export BAO_ADDR=https://${local.openbao_hostname}
      bao login -method=oidc -path=oidc role=default
      ```

      Your team prefix is `${team_key}`. List team prefixes, list your secrets, and read this guide with:

      ```bash
      bao kv list kv2
      bao kv list kv2/${team_key}
      bao kv get kv2/${team_key}/README
      ```

      Create or update a secret under your team prefix with:

      ```bash
      bao kv put kv2/${team_key}/my-secret example=value
      ```

      Team access is granted through the `openbao-secret-readers`, `openbao-secret-writers`,
      and `openbao-secret-admins` groups. Readers can list and read; writers can create and update;
      admins can also manage secret metadata and versions. Do not store credentials in source
      repositories or CI settings.
    EOT
  }

  team_policy_documents = {
    for key, paths in local.team_policy_paths : key => join("\n\n", [
      for path in paths : format(
        "path \"%s\" {\n  capabilities = %s\n}",
        path.path,
        jsonencode(path.capabilities),
      )
    ])
  }

  team_policy_paths = {
    for key, group in local.openbao_groups : key => concat(
      [
        {
          capabilities = ["list"]
          path         = "kv2/metadata"
        },
        {
          capabilities = group.access == "readers" ? ["read"] : group.access == "writers" ? ["create", "read", "update"] : ["create", "delete", "read", "update"]
          path         = "kv2/data/${group.team_key}/*"
        },
        {
          capabilities = group.access == "admins" ? ["create", "delete", "list", "read", "update"] : ["list", "read"]
          path         = "kv2/metadata/${group.team_key}/*"
        },
        {
          capabilities = ["list", "read"]
          path         = "kv2/metadata/${group.team_key}"
        },
      ],
      group.access == "admins" ? [
        {
          capabilities = ["update"]
          path         = "kv2/delete/${group.team_key}/*"
        },
        {
          capabilities = ["update"]
          path         = "kv2/destroy/${group.team_key}/*"
        },
        {
          capabilities = ["update"]
          path         = "kv2/undelete/${group.team_key}/*"
        },
      ] : [],
    )
  }
}
