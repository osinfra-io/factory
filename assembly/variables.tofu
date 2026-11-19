variable "billing_account_id" {
  description = "Existing billing account for Assembly-managed Sandbox projects"
  type        = string

  validation {
    condition     = can(regex("^[A-Z0-9]{6}-[A-Z0-9]{6}-[A-Z0-9]{6}$", var.billing_account_id))
    error_message = "Provide a billing account ID in XXXXXX-XXXXXX-XXXXXX format."
  }
}

variable "bucket" {
  description = "GCS bucket containing the environment's Foundation state"
  type        = string
}

variable "cluster_subnets" {
  description = "Platform-assigned IPv4 subnet ranges by team and cluster location"
  type = map(map(object({
    control_plane = string
    nodes         = string
    pods          = string
    services      = string
  })))

  validation {
    condition = alltrue(flatten([
      for locations in values(var.cluster_subnets) : [
        for ranges in values(locations) : [for cidr in values(ranges) : can(cidrnetmask(cidr))]
      ]
    ]))
    error_message = "Cluster subnet allocations must be valid IPv4 CIDR ranges."
  }
}

variable "environment" {
  description = "Environment managed by this Assembly workspace"
  type        = string

  validation {
    condition     = var.environment == "sandbox"
    error_message = "The initial Assembly workspace supports only Sandbox."
  }
}

variable "external_service_projects" {
  default     = []
  description = "Existing project IDs explicitly approved by the platform to attach to the Sandbox Shared VPC"
  type        = set(string)

  validation {
    condition     = alltrue([for project in var.external_service_projects : can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", project))])
    error_message = "External service projects must be valid Google Cloud project IDs."
  }
}

variable "github_repository_owner_id" {
  default     = null
  description = "Immutable GitHub organization ID trusted for registry publishing, not infrastructure deployments"
  type        = string

  validation {
    condition     = var.github_repository_owner_id == null || can(regex("^[0-9]+$", var.github_repository_owner_id))
    error_message = "The GitHub repository owner ID must be numeric."
  }
}

variable "host_project_team" {
  description = "Declared team whose key prefixes the environment's shared host project ID"
  type        = string

  validation {
    condition     = contains(keys(var.teams), var.host_project_team)
    error_message = "The shared host project's prefix must be a declared team key."
  }
}

variable "monthly_project_budgets" {
  default     = {}
  description = "Monthly project budgets in USD for the Shared VPC host, team projects, and workload projects"
  type = object({
    host     = optional(number, 5)
    team     = optional(number, 5)
    workload = optional(number, 5)
  })

  validation {
    condition     = alltrue([for amount in values(var.monthly_project_budgets) : amount > 0])
    error_message = "Monthly project budgets must be greater than zero."
  }
}

variable "private_service_range" {
  description = "Platform-assigned IPv4 CIDR for private services access"
  type        = string

  validation {
    condition     = can(cidrnetmask(var.private_service_range))
    error_message = "The private services range must be a valid IPv4 CIDR."
  }
}

variable "prefix" {
  description = "GCS prefix for the environment's Foundation state, separate from Assembly's state"
  type        = string

  validation {
    condition     = var.prefix == "foundation"
    error_message = "Assembly reads Foundation state from the foundation prefix."
  }
}

variable "runtime_project_access" {
  default     = {}
  description = "Platform-owned Runtime IAM grants by team, role, and principal in workload projects"
  type        = map(map(set(string)))

  validation {
    condition     = alltrue([for team in keys(var.runtime_project_access) : contains(keys(local.workload_teams), team)])
    error_message = "Runtime IAM grants must target a team with a managed workload project."
  }
}

variable "teams" {
  description = "Teams declared in the Factory team tfvars"
  type = map(object({
    artifact_registry = optional(object({
      github_repository_ids = optional(set(string), [])
      readers               = optional(set(string), [])
      writers               = optional(set(string), [])
    }))
    cloud_sql = optional(map(object({
      database_version = string
      machine_tier     = string
      regions          = set(string)
    })), {})
    display_name = string
    google_project = optional(object({
      administrators = optional(set(string), [])
      services       = optional(set(string), [])
    }))
    kubernetes_engine = optional(object({
      dns_subdomain    = optional(string)
      dns_writers      = optional(set(string), [])
      registry_pullers = optional(set(string), [])
      locations = map(object({
        enable_gke_hub_host = optional(bool, false)
      }))
    }))
    opentofu_state = optional(object({
      readers = optional(set(string), [])
      writers = optional(set(string), [])
    }))
  }))

  validation {
    condition = alltrue(flatten([
      for team, config in var.teams : [
        for location in keys(config.kubernetes_engine.locations) :
        can(regex("^(us-east1|us-east4)-[a-f]$", location)) && can(var.cluster_subnets[team][location])
      ] if config.kubernetes_engine != null
    ]))
    error_message = "Every requested GKE location must be a zone with a subnet allocation for that team."
  }

  validation {
    condition = alltrue(flatten([
      for config in values(var.teams) : [
        for name, instance in config.cloud_sql :
        can(regex("^[a-z]([a-z0-9-]{0,46}[a-z0-9])?$", name)) &&
        length(instance.regions) > 0 && length(setsubtract(instance.regions, ["us-east1", "us-east4"])) == 0
      ]
    ]))
    error_message = "Cloud SQL instances need lowercase names (up to 48 characters) and at least one supported region: us-east1 or us-east4."
  }

  validation {
    condition = alltrue([
      for team, config in var.teams :
      can(regex("^[a-z][a-z0-9-]{0,16}[a-z0-9]$", team)) &&
      can(regex("^[a-z]([a-z0-9-]{0,61}[a-z0-9])?$", coalesce(try(config.kubernetes_engine.dns_subdomain, null), team)))
    ])
    error_message = "Team keys must be 2-18 character lowercase resource names and DNS subdomains must be valid labels."
  }

  validation {
    condition = alltrue(flatten([
      for config in values(var.teams) : [
        for id in config.artifact_registry.github_repository_ids :
        var.github_repository_owner_id != null && can(regex("^[0-9]+$", id))
      ] if config.artifact_registry != null
    ]))
    error_message = "GitHub publishing requires numeric repository IDs and an explicit trusted owner ID."
  }
}
