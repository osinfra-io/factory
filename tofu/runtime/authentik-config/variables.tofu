variable "bucket" {
  description = "GCS bucket containing the environment's Runtime and Assembly state"
  type        = string
}

variable "google_oauth_client_id" {
  default     = ""
  description = "OAuth client ID for the optional Google login source; leave empty to disable the source and the managed application groups"
  type        = string
}

variable "google_oauth_client_secret" {
  default     = ""
  description = "OAuth client secret for the optional Google login source; leave empty to disable the source and the managed application groups"
  sensitive   = true
  type        = string
}

variable "locations" {
  default     = ["us-east1-b", "us-east4-a"]
  description = "Zones that run a Runtime cluster in this environment"
  type        = list(string)
}

variable "team" {
  default     = "factory"
  description = "Team that owns the authentik application groups and the test workload"
  type        = string
}

variable "teams" {
  description = "Team declarations whose authentik_groups become application access groups; supplied by teams.auto.tfvars"
  type = map(object({
    authentik_groups = optional(map(object({
      description = string
      label       = optional(string)
      name        = optional(string)
      members = optional(object({
        non-production = optional(list(string), [])
        production     = optional(list(string), [])
        sandbox        = optional(list(string), [])
      }), {})
    })), {})
  }))
}
