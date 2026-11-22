output "oidc_auth_mount_path" {
  description = "Path of the openbao OIDC authentication mount"
  value       = vault_jwt_auth_backend.oidc.path
}

output "team_kv2_mount_path" {
  description = "Path of the team-scoped KV v2 mount"
  value       = vault_mount.team_kv2.path
}
