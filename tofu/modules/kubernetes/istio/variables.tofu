# Input Variables
# https://opentofu.org/docs/language/values/variables

variable "gateway_attach_retained_certificates" {
  default     = true
  description = "Whether retained certificates stay attached to the load balancer. Set it to false once the current certificate is ACTIVE and keep the retained domain sets until the regional workspaces have detached them"
  type        = bool
}

variable "gateway_dns" {
  default     = {}
  description = "Map of attributes for the Istio gateway domain names, it is also used to create the managed certificate resource"
  type = map(object({
    managed_zone = string
    project      = string
  }))
}

variable "gateway_retained_domain_sets" {
  default     = []
  description = "Previous gateway domain sets whose certificates are kept alongside the current one. Clear it only after the load balancer has detached those certificates (see gateway_attach_retained_certificates), so a certificate is never deleted while it is in use"
  type        = list(list(string))
}

variable "gke_fleet_host_project_id" {
  default     = ""
  description = "The project ID of the GKE Hub host project"
  type        = string
}

variable "labels" {
  default     = {}
  description = "A map of key/value pairs to assign to the resources being created"
  type        = map(string)
}

variable "project" {
  description = "The ID of the project in which the resource belongs"
  type        = string
}
