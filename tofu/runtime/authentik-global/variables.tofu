variable "bucket" {
  description = "GCS bucket containing the environment's Assembly state"
  type        = string
}

variable "team" {
  default     = "factory"
  description = "Team whose workload project hosts the authentik database"
  type        = string
}
