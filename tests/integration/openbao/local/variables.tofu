# Input Variables
# https://opentofu.org/docs/language/values/variables

variable "hostname" {
  default     = "openbao.localhost"
  description = "Local hostname routed through the Istio ingress Gateway"
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
  description = "Namespace containing OpenBao"
  type        = string
}

variable "service_name" {
  default     = "openbao"
  description = "OpenBao Service name"
  type        = string
}

variable "service_port" {
  default     = 8200
  description = "OpenBao Service port"
  type        = number
}
