# Input Variables
# https://opentofu.org/docs/language/values/variables

variable "allowed_groups" {
  default     = ["system:masters"]
  description = "Kubernetes groups permitted to manage protected gateway authentication resources"
  type        = list(string)
}

variable "allowed_users" {
  default     = []
  description = "Kubernetes usernames permitted to manage protected gateway authentication resources"
  type        = list(string)
}

variable "protected_kinds" {
  default = [
    {
      apiGroup = "networking.istio.io"
      kind     = "EnvoyFilter"
    },
    {
      apiGroup = "security.istio.io"
      kind     = "AuthorizationPolicy"
    },
    {
      apiGroup = "security.istio.io"
      kind     = "RequestAuthentication"
    },
  ]

  description = "Kubernetes resource kinds that only allowed users and groups may manage"

  type = list(object({
    apiGroup = string
    kind     = string
  }))

  validation {
    condition = alltrue([
      for protected_kind in var.protected_kinds :
      protected_kind.kind != "" &&
      protected_kind.kind == trimspace(protected_kind.kind) &&
      (protected_kind.apiGroup == "" || protected_kind.apiGroup == trimspace(protected_kind.apiGroup))
    ])
    error_message = "Each protected_kinds entry must have a non-empty, whitespace-trimmed kind and a whitespace-trimmed apiGroup."
  }
}

variable "protected_namespaces" {
  default     = ["authentik"]
  description = "Kubernetes namespaces whose lifecycle and Secrets only allowed users and groups may manage"
  type        = list(string)

  validation {
    condition = alltrue([
      for namespace in var.protected_namespaces :
      namespace != "" && namespace == trimspace(namespace)
    ])
    error_message = "protected_namespaces entries must be non-empty and whitespace-trimmed."
  }
}
