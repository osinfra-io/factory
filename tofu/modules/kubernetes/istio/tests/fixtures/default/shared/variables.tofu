# Input Variables
# https://opentofu.org/docs/language/values/variables

variable "gateway_attach_retained_certificates" {
  default     = true
  description = "Whether retained certificates stay attached"
  type        = bool
}

variable "gateway_dns" {
  description = "Map of DNS configurations for the Istio Gateway"
  type = map(object({
    managed_zone = string
    project      = string
  }))
}

variable "gateway_retained_domain_sets" {
  default     = []
  description = "Previous gateway domain sets whose certificates are kept"
  type        = list(list(string))
}

variable "project" {
  description = "The GCP project ID"
  type        = string
}
