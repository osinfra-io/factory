# Input Variables
# https://opentofu.org/docs/language/values/variables

variable "artifact_registry" {
  default     = "us-docker.pkg.dev/plt-lz-services-tf79-prod/plt-docker-virtual"
  description = "The registry to pull the images from"
  type        = string
}

variable "audit_resources_limits_cpu" {
  default     = "40m"
  description = "The CPU limit for the audit container"
  type        = string

  validation {
    condition     = can(regex("^([0-9]*\\.?[0-9]+)(m)?$", var.audit_resources_limits_cpu))
    error_message = "The audit_resources_limits_cpu value must be a valid Kubernetes CPU quantity (e.g., '40m', '0.1', '1')."
  }
}

variable "audit_resources_limits_memory" {
  default     = "128Mi"
  description = "The memory limit for the audit container"
  type        = string

  validation {
    condition     = can(regex("^([0-9]*\\.?[0-9]+)(Ei|Pi|Ti|Gi|Mi|Ki|E|P|T|G|M|K)?$", var.audit_resources_limits_memory))
    error_message = "The audit_resources_limits_memory value must be a valid Kubernetes memory quantity (e.g., '128Mi', '1Gi', '512M')."
  }
}

variable "audit_resources_requests_cpu" {
  default     = "10m"
  description = "The CPU request for the audit container"
  type        = string

  validation {
    condition     = can(regex("^([0-9]*\\.?[0-9]+)(m)?$", var.audit_resources_requests_cpu))
    error_message = "The audit_resources_requests_cpu value must be a valid Kubernetes CPU quantity (e.g., '10m', '0.1', '1')."
  }
}

variable "audit_resources_requests_memory" {
  default     = "32Mi"
  description = "The memory request for the audit container"
  type        = string

  validation {
    condition     = can(regex("^([0-9]*\\.?[0-9]+)(Ei|Pi|Ti|Gi|Mi|Ki|E|P|T|G|M|K)?$", var.audit_resources_requests_memory))
    error_message = "The audit_resources_requests_memory value must be a valid Kubernetes memory quantity (e.g., '32Mi', '1Gi', '256M')."
  }
}

variable "chart_repository" {
  default     = "https://open-policy-agent.github.io/gatekeeper/charts"
  description = "The repository to pull the Helm chart from"
  type        = string
}

variable "controller_manager_resources_limits_cpu" {
  default     = "100m"
  description = "The CPU limit for the controller manager container"
  type        = string
}

variable "controller_manager_resources_limits_memory" {
  default     = "256Mi"
  description = "The memory limit for the controller manager container"
  type        = string
}

variable "controller_manager_resources_requests_cpu" {
  default     = "10m"
  description = "The CPU request for the controller manager container"
  type        = string
}

variable "controller_manager_resources_requests_memory" {
  default     = "32Mi"
  description = "The memory request for the controller manager container"
  type        = string
}

variable "gatekeeper_version" {
  default     = "v3.23.1"
  description = "The version to install, this is used for the chart as well as the image tag"
  type        = string
}

variable "replicas" {
  default     = 1
  description = "The number of replicas to run"
  type        = number
}
