variable "bucket" {
  description = "GCS bucket containing the environment's Runtime and Assembly state"
  type        = string
}

variable "openbao_zone" {
  default     = "us-east1-b"
  description = "Zone whose openbao instance this stage configures"
  type        = string
}

variable "teams" {
  description = "Team declarations whose openbao-secret-* authentik_groups become openbao groups; supplied by teams.auto.tfvars"
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
