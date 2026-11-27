# Input Variables
# https://opentofu.org/docs/language/values/variables

variable "cainjector_replicas" {
  default     = 1
  description = "The number of replicas to run for the cainjector"
  type        = number
}

variable "cainjector_resources_limits_cpu" {
  default     = "20m"
  description = "The CPU limit for the cainjector resources"
  type        = string
}

variable "cainjector_resources_limits_memory" {
  default     = "64Mi"
  description = "The memory limit for the cainjector resources"
  type        = string
}

variable "cainjector_resources_requests_cpu" {
  default     = "10m"
  description = "The CPU request for the cainjector resources"
  type        = string
}

variable "cainjector_resources_requests_memory" {
  default     = "32Mi"
  description = "The memory request for the cainjector resources"
  type        = string
}

variable "cert_manager_version" {
  default     = "1.21.3"
  description = "The version to install, this is used for the chart as well as the image tag"
  type        = string
}

variable "chart_repository" {
  default     = "https://charts.jetstack.io"
  description = "The repository to pull the cert-manager Helm chart from"
  type        = string
}

variable "replicas" {
  default     = 1
  description = "The number of replicas to run"
  type        = number
}

variable "resources_limits_cpu" {
  default     = "20m"
  description = "The CPU limit for the resources"
  type        = string
}

variable "resources_limits_memory" {
  default     = "64Mi"
  description = "The memory limit for the resources"
  type        = string
}

variable "resources_requests_cpu" {
  default     = "10m"
  description = "The CPU request for the resources"
  type        = string
}

variable "resources_requests_memory" {
  default     = "32Mi"
  description = "The memory request for the resources"
  type        = string
}

variable "startupapicheck_resources_limits_cpu" {
  default     = "20m"
  description = "The CPU limit for the startupapicheck resources"
  type        = string
}

variable "startupapicheck_resources_limits_memory" {
  default     = "64Mi"
  description = "The memory limit for the startupapicheck resources"
  type        = string
}

variable "startupapicheck_resources_requests_cpu" {
  default     = "10m"
  description = "The CPU request for the startupapicheck resources"
  type        = string
}

variable "startupapicheck_resources_requests_memory" {
  default     = "32Mi"
  description = "The memory request for the startupapicheck resources"
  type        = string
}

variable "webhook_replicas" {
  default     = 1
  description = "The number of replicas to run for the webhook"
  type        = number
}

variable "webhook_resources_limits_cpu" {
  default     = "20m"
  description = "The CPU limit for the webhook resources"
  type        = string
}

variable "webhook_resources_limits_memory" {
  default     = "64Mi"
  description = "The memory limit for the webhook resources"
  type        = string
}

variable "webhook_resources_requests_cpu" {
  default     = "10m"
  description = "The CPU request for the webhook resources"
  type        = string
}

variable "webhook_resources_requests_memory" {
  default     = "32Mi"
  description = "The memory request for the webhook resources"
  type        = string
}
