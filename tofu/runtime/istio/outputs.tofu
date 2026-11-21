output "reader_token" {
  description = "Token of the istio-reader service account that peer clusters use for cross-cluster discovery"
  sensitive   = true
  value       = try(kubernetes_secret_v1.istio_reader["this"].data["token"], null)
}
