# Input Variables
# https://opentofu.org/docs/language/values/variables

variable "authentik_token" {
  description = "Local authentik bootstrap API token"
  sensitive   = true
  type        = string
}

variable "embedded_outpost_id" {
  description = "UUID of the built-in outpost discovered during bootstrap"
  type        = string
}

variable "environment" {
  description = "Environment whose Factory access policy the local fixture exercises"
  type        = string

  validation {
    condition = var.environment == "sandbox"

    error_message = "The local integration fixture must exercise the Sandbox access policy."
  }
}

variable "google_oauth_client_id" {
  description = "Google web OAuth client with the registered localhost callback"
  sensitive   = true
  type        = string

  validation {
    condition = length(var.google_oauth_client_id) > 0

    error_message = "Local integration requires Google OAuth credentials."
  }
}

variable "google_oauth_client_secret" {
  description = "Google OAuth secret supplied through the developer environment"
  sensitive   = true
  type        = string

  validation {
    condition = length(var.google_oauth_client_secret) > 0

    error_message = "Local integration requires Google OAuth credentials."
  }

}

variable "import_built_in_brand" {
  default     = true
  description = "Import the built-in brand so it can be demoted; disabled only by mocked tests, which cannot import"
  type        = bool
}

variable "local_test_user_email" {
  default     = null
  description = "Lowercase Google email for local integration access, populated from Git user.email during setup."
  type        = string
}

variable "revoke_application_access" {
  default     = false
  description = "Local-only revocation test: temporarily empty declared application memberships without changing diagnostic access."
  type        = bool
}

variable "teams" {
  description = "Factory team access declarations shared with the environment configuration"
  type = map(object({
    authentik_groups = map(object({
      description = string
      label       = optional(string)
      name        = optional(string)
      members = optional(object({
        non-production = optional(list(string), [])
        production     = optional(list(string), [])
        sandbox        = optional(list(string), [])
      }), {})
    }))
  }))
}
