# Input Variables
# https://opentofu.org/docs/language/values/variables

variable "cert_manager_istio_csr_version" {
  default     = "0.19.1"
  description = "The version to install for the Istio CSR, this is used for the chart as well as the image tag"
  type        = string
}

variable "chart_repository" {
  default     = "https://charts.jetstack.io"
  description = "The repository to pull the cert-manager Helm chart from"
  type        = string
}

variable "cluster_prefix" {
  description = "Prefix for your cluster name, region, and zone (if applicable) will be added to the end of the cluster name"
  type        = string
}

variable "resources_limits_cpu" {
  default     = "50m"
  description = "The CPU limit for the Istio CSR container"
  type        = string
}

variable "resources_limits_memory" {
  default     = "64Mi"
  description = "The memory limit for the Istio CSR container"
  type        = string
}

variable "resources_requests_cpu" {
  default     = "25m"
  description = "The CPU request for the Istio CSR container"
  type        = string
}

variable "resources_requests_memory" {
  default     = "32Mi"
  description = "The memory request for the Istio CSR container"
  type        = string
}

variable "tls_self_signed_cert_cert_manager_root_cert" {
  description = "The self-signed certificate for the cert-manager root certificate"
  type        = string
}

variable "tls_self_signed_cert_cert_manager_root_key" {
  description = "The private key for the cert-manager root certificate"
  sensitive   = true
  type        = string
}

variable "trusted_node_service_accounts" {
  default     = ["istio-system/ztunnel"]
  description = "Service accounts, in the form namespace/name, allowed to use node authentication for CSRs (e.g. Istio ambient's ztunnel)"
  type        = list(string)
}
