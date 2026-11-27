# Output Values
# https://opentofu.org/docs/language/values/outputs

output "name" {
  description = "The name of the authentik Helm release"
  value       = helm_release.authentik.name
}

output "namespace" {
  description = "The namespace authentik is deployed into"
  value       = helm_release.authentik.namespace
}
