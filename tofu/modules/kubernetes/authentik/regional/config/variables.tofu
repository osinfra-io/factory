# Input Variables
# https://opentofu.org/docs/language/values/variables

variable "authentik_url" {
  description = "The public Authentik base URL used when no outpost-specific URL is provided"
  type        = string

  validation {
    condition     = startswith(var.authentik_url, "https://")
    error_message = "The authentik_url must be a public HTTPS URL (starting with https://)."
  }
}

variable "namespace" {
  description = "The Kubernetes namespace containing the regional authentik-server that serves the embedded outpost"
  type        = string
}

variable "outpost_authentik_url" {
  default     = null
  description = "Optional browser-accessible Authentik base URL used by the regional embedded outpost"
  nullable    = true
  type        = string

  validation {
    condition = var.outpost_authentik_url == null ? true : anytrue([
      startswith(var.outpost_authentik_url, "https://"),
      startswith(var.outpost_authentik_url, "http://localhost:"),
      startswith(var.outpost_authentik_url, "http://127.0.0.1:"),
    ])
    error_message = "The outpost_authentik_url must use HTTPS, except for local development URLs on localhost or 127.0.0.1."
  }
}

variable "proxy_provider_ids" {
  description = "IDs of the instance-wide proxy providers assigned to the regional embedded outpost"
  type        = list(number)
}
