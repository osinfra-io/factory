variable "bucket" {
  description = "GCS bucket containing the environment's Assembly state"
  type        = string
}

variable "team" {
  default     = "factory"
  description = "Team whose workload project and DNS zone host the Istio gateway"
  type        = string
}
