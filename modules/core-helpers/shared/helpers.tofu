# Core Helpers
# https://github.com/osinfra-io/factory

locals {
  # The regex parses the workspace name into its components to set region, zone, and environment.

  env = local.environment != null ? lookup(local.env_map, local.environment, "none") : null

  env_map = {
    "non-production" = "nonprod"
    "production"     = "prod"
    "sandbox"        = "sb"
  }

  environment = local.parsed_workspace.environment

  environment_regex = "-(non-production|sandbox|production)$"

  parsed_workspace = (
    local.workspace == "default" ?
    {
      environment = "mock-environment"
      region      = "mock-region"
      zone        = "mock-zone"
    } :
    {
      environment = try(regex(local.environment_regex, local.workspace)[0], null)
      region      = try(regex(local.region_regex, local.workspace)[0], null)
      zone        = try(regex(local.zone_regex, local.workspace)[1], null)
    }
  )

  region = local.parsed_workspace.region

  region_regex = "^(us-east1|us-east4)(-|$)"

  workspace = var.workspace != null ? var.workspace : terraform.workspace

  zone = local.parsed_workspace.zone

  zone_regex = "^(us-east1|us-east4)-([abcdef])(-|$)"
}

output "env" {
  description = "The short name for the environment, for example prod, nonprod, sb"
  value       = local.env
}

output "environment" {
  description = "The full environment name, for example production, non-production, sandbox"
  value       = local.environment
}

output "region" {
  description = "The region of the current workspace"
  value       = local.region
}

output "zone" {
  description = "The zone of the current workspace"
  value       = local.zone
}

variable "workspace" {
  description = "Workspace name override used by tests"
  type        = string
  default     = null
}
