# Input Variables
# https://opentofu.org/docs/language/values/variables

variable "labels" {
  default     = {}
  description = "Labels applied to agentgateway resources"
  type        = map(string)
}

variable "namespace" {
  description = "Kubernetes namespace for agentgateway"
  type        = string
}

variable "proxy_cpu_limits" {
  default     = "500m"
  description = "CPU limit for the agentgateway proxy"
  type        = string
}

variable "proxy_cpu_requests" {
  default     = "100m"
  description = "CPU request for the agentgateway proxy"
  type        = string
}

variable "proxy_env" {
  default     = {}
  description = "Additional environment variables for the agentgateway proxy"
  type        = map(string)
}

variable "proxy_memory_limits" {
  default     = "512Mi"
  description = "Memory limit for the agentgateway proxy"
  type        = string
}

variable "proxy_memory_requests" {
  default     = "128Mi"
  description = "Memory request for the agentgateway proxy"
  type        = string
}

variable "proxy_replicas" {
  default     = 1
  description = "Number of agentgateway proxy replicas"
  type        = number

  validation {
    condition = var.proxy_replicas > 0

    error_message = "proxy_replicas must be greater than zero."
  }
}
