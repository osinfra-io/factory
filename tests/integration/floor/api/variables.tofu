# Input Variables
# https://opentofu.org/docs/language/values/variables

variable "additional_namespaces" {
  default     = []
  description = "Opt-in namespaces exposed alongside the disposable local floor fixture namespace"
  type        = set(string)

  validation {
    condition = alltrue([
      for namespace in var.additional_namespaces :
      can(regex("^[a-z0-9]([-a-z0-9]{0,61}[a-z0-9])?$", namespace))
    ])
    error_message = "Additional namespaces must be valid Kubernetes namespace names."
  }

  validation {
    condition     = !contains(var.additional_namespaces, var.fixture_namespace)
    error_message = "The fixture namespace is already exposed and must not be repeated."
  }
}

variable "approver_group" {
  default     = "fixture: Floor Verification Approvers"
  description = "authentik group whose members may approve plans through floor-api"
  type        = string
}

variable "authentik_http_port" {
  default     = 80
  description = "HTTP port exposed by the authentik server Service"
  type        = number
}

variable "authentik_namespace" {
  default     = "authentik"
  description = "Namespace containing the authentik server"
  type        = string
}

variable "authentik_service" {
  default     = "authentik-server"
  description = "authentik server Service name"
  type        = string
}

variable "fixture_namespace" {
  default     = "floor-fixture"
  description = "Namespace holding the floor fixture Terraform objects"
  type        = string
}

variable "gateway_name" {
  default     = "agentgateway-proxy"
  description = "agentgateway Gateway name"
  type        = string
}

variable "gateway_namespace" {
  default     = "agentgateway"
  description = "Namespace containing the agentgateway Gateway"
  type        = string
}

variable "gateway_principal" {
  default     = "cluster.local/ns/agentgateway/sa/agentgateway-proxy"
  description = "Istio principal of the agentgateway proxy, the only workload allowed to reach floor-api"
  type        = string
}

variable "git_repository" {
  default     = "fixture"
  description = "GitRepository the sandbox repoints at a pull request head"
  type        = string
}

variable "github_repository" {
  default     = "osinfra-io/factory-floor-fixture"
  description = "Owner and repository of the floor fixture configuration"
  type        = string
}

variable "github_token_checksum" {
  description = "Checksum of the GitHub token secret, which rolls the pods when the token changes"
  type        = string
}

variable "github_token_secret" {
  default     = "floor-github-token"
  description = "Secret holding the GitHub token floor-api reads pull requests and writes comments with"
  type        = string
}

variable "hostname" {
  default     = "floor.localhost"
  description = "Local hostname routed through the Istio ingress Gateway"
  type        = string
}

variable "image" {
  default     = "factory-floor-api:local"
  description = "floor-api container image"
  type        = string
}

variable "istio_gateway_name" {
  default     = "gateway"
  description = "Istio ingress Gateway name"
  type        = string
}

variable "istio_gateway_namespace" {
  default     = "istio-ingress"
  description = "Namespace containing the Istio ingress Gateway"
  type        = string
}

variable "namespace" {
  default     = "floor-system"
  description = "Namespace containing floor-api"
  type        = string
}

variable "request_timeout" {
  default     = "240s"
  description = "HTTPRoute request timeout, above the floor-api revision timeout so an approve is not cut short while the planner re-plans"
  type        = string
}

variable "service_port" {
  default     = 8080
  description = "Port floor-api listens on"
  type        = number
}
