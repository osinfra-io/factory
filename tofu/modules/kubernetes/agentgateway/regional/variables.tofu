# Input Variables
# https://opentofu.org/docs/language/values/variables

variable "agentgateway_version" {
  default     = "v1.6.0"
  description = "agentgateway Helm chart version"
  type        = string
}

variable "chart_repository" {
  default     = "oci://cr.agentgateway.dev/charts"
  description = "OCI repository containing the agentgateway Helm charts"
  type        = string
}

variable "controller_cpu_limits" {
  default     = "500m"
  description = "CPU limit for the agentgateway controller"
  type        = string
}

variable "controller_cpu_requests" {
  default     = "100m"
  description = "CPU request for the agentgateway controller"
  type        = string
}

variable "controller_memory_limits" {
  default     = "512Mi"
  description = "Memory limit for the agentgateway controller"
  type        = string
}

variable "controller_memory_requests" {
  default     = "128Mi"
  description = "Memory request for the agentgateway controller"
  type        = string
}

variable "crds_postrender" {
  default     = null
  description = "Optional Helm post-renderer for the CRD chart; local fixtures use it to retain cluster-wide CRDs on uninstall"
  type = object({
    args        = optional(list(string), [])
    binary_path = string
  })
}

variable "labels" {
  default     = {}
  description = "Labels applied to agentgateway resources"
  type        = map(string)
}

variable "namespace" {
  description = "Kubernetes namespace for agentgateway"
  type        = string
}
