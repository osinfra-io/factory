# Output Values
# https://opentofu.org/docs/language/values/outputs

output "admin_policy_manifest" {
  description = "agentgateway admin-port deny policy"
  value       = kubernetes_manifest.agentgateway_admin_authorization.manifest
}

output "admin_route_manifest" {
  description = "Istio ingress route to the authenticated agentgateway admin UI"
  value       = kubernetes_manifest.agentgateway_admin.manifest
}

output "admin_service" {
  description = "ClusterIP Service exposing the agentgateway admin port to the mesh"
  value       = kubernetes_service_v1.agentgateway_admin
}

output "authentik_outpost_route_manifest" {
  description = "Istio ingress route to the authentik outpost"
  value       = kubernetes_manifest.authentik_outpost.manifest
}

output "diagnostic_ingress_manifest" {
  description = "Istio ingress route to the agentgateway diagnostic endpoint"
  value       = kubernetes_manifest.agentgateway_ingress.manifest
}

output "diagnostic_route_manifest" {
  description = "agentgateway route to the shared diagnostic workload"
  value       = kubernetes_manifest.agentgateway_backend.manifest
}
