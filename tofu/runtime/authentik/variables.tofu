variable "server_replicas" {
  default     = 1
  description = "Number of authentik server replicas"
  type        = number
}

variable "server_resources_requests_cpu" {
  default     = "250m"
  description = "authentik server CPU request"
  type        = string
}

variable "server_resources_requests_memory" {
  default     = "768Mi"
  description = "authentik server memory request"
  type        = string
}

variable "worker_replicas" {
  default     = 1
  description = "Number of authentik worker replicas"
  type        = number
}

variable "worker_resources_requests_cpu" {
  default     = "250m"
  description = "authentik worker CPU request"
  type        = string
}

variable "worker_resources_requests_memory" {
  default     = "384Mi"
  description = "authentik worker memory request"
  type        = string
}
