# Input Variables
# https://opentofu.org/docs/language/values/variables

variable "anti_affinity_enabled" {
  default     = true
  description = "Require OpenBao server pods to schedule on different nodes; disable only for single-node fixtures"
  type        = bool
}

variable "chart_repository" {
  default     = "https://openbao.github.io/openbao-helm"
  description = "Helm repository containing the OpenBao chart"
  type        = string
}

variable "cpu_limits" {
  default     = "250m"
  description = "CPU limit for each OpenBao server pod"
  type        = string
}

variable "cpu_requests" {
  default     = "250m"
  description = "CPU request for each OpenBao server pod"
  type        = string
}

variable "labels" {
  default     = {}
  description = "Labels applied to OpenBao server pods"
  type        = map(string)
}

variable "memory_limits" {
  default     = "256Mi"
  description = "Memory limit for each OpenBao server pod"
  type        = string
}

variable "memory_requests" {
  default     = "256Mi"
  description = "Memory request for each OpenBao server pod"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for OpenBao"
  type        = string
}

variable "openbao_version" {
  default     = "0.27.0"
  description = "OpenBao Helm chart version"
  type        = string
}

variable "raft_configuration" {
  default     = ""
  description = "Complete OpenBao server HCL configuration for Raft mode, replacing the chart default; must include a listener, Raft storage, and any required service registration and seal settings"
  nullable    = false
  type        = string
}

variable "replicas" {
  default     = 3
  description = "Number of OpenBao Raft server replicas"
  type        = number
}

variable "server_annotations" {
  default     = {}
  description = "Additional annotations applied to OpenBao server pods"
  type        = map(string)
}

variable "server_config_annotation" {
  default     = false
  description = "Include a configuration checksum in the server pod template; automatic restarts also require RollingUpdate and a suitable unseal procedure"
  type        = bool
}

variable "server_extra_environment_vars" {
  default     = {}
  description = "Additional environment variables for OpenBao server pods"
  type        = map(string)
}

variable "server_extra_volumes" {
  default     = []
  description = "Additional volumes mounted by OpenBao server pods"
  type = list(object({
    name = string
    type = string
  }))
}

variable "server_service_account_annotations" {
  default     = {}
  description = "Annotations applied to the OpenBao server Kubernetes service account"
  type        = map(string)
}

variable "server_service_account_name" {
  default     = "openbao"
  description = "Name of the Kubernetes service account used by OpenBao server pods"
  type        = string
}

variable "server_update_strategy_type" {
  default     = "OnDelete"
  description = "Update strategy used for the OpenBao server StatefulSet; opt into RollingUpdate only with a suitable unseal procedure"
  type        = string
}

variable "service_annotations" {
  default     = {}
  description = "Annotations applied to the OpenBao Service, such as GKE backend configuration"
  type        = map(string)
}

variable "service_type" {
  default     = "ClusterIP"
  description = "Kubernetes Service type for OpenBao; GKE Ingress requires NodePort"
  type        = string
}

variable "tls_disable" {
  default     = true
  description = "Disable TLS for OpenBao listeners"
  type        = bool

  validation {
    condition = var.tls_disable || trimspace(var.raft_configuration) != ""

    error_message = "Setting tls_disable to false requires a complete raft_configuration with a TLS-enabled listener, certificate/key paths, and Raft storage; supply the required certificate mounts separately."
  }
}
