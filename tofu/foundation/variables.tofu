# Input Variables
# https://opentofu.org/docs/language/values/variables

variable "environment" {
  description = "The environment managed by this Foundation workspace"
  type        = string

  validation {
    condition     = contains(["non-production", "production", "sandbox"], var.environment)
    error_message = "The environment must be sandbox, non-production, or production."
  }
}

variable "google_environment_root_folder_id" {
  description = "The existing folder ID for the current environment"
  type        = string

  validation {
    condition     = can(regex("^[0-9]+$", var.google_environment_root_folder_id))
    error_message = "The environment root folder ID must contain only digits."
  }
}

variable "google_quota_project" {
  description = "Google Cloud project ID used for API quota"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.google_quota_project))
    error_message = "The quota project must be a valid Google Cloud project ID."
  }
}

variable "teams" {
  description = "Factory team metadata; Foundation currently supports only the Factory team"
  type = map(object({
    display_name = string
  }))

  validation {
    condition = toset(keys(var.teams)) == toset(["factory"])

    error_message = "Foundation must declare exactly one team with the key \"factory\"."
  }

}
