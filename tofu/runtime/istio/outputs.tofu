output "reader_token" {
  description = "Token of the istio-reader service account that peer clusters use for cross-cluster discovery"
  sensitive   = true
  value       = local.reader_token_output
}
