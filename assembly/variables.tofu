variable "bucket" {
  description = "GCS bucket containing the environment's Foundation state"
  type        = string
}

variable "environment" {
  description = "Environment managed by this Assembly workspace"
  type        = string

  validation {
    condition     = var.environment == "sandbox"
    error_message = "The initial Assembly workspace supports only Sandbox."
  }
}

variable "prefix" {
  description = "GCS prefix for the environment's Foundation state, separate from Assembly's state"
  type        = string
}

variable "teams" {
  description = "Teams declared in the Factory team tfvars"
  type = map(object({
    display_name = string
  }))
}
