# Input Variables
# https://opentofu.org/docs/language/values/variables

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

variable "data_port" {
  default     = 80
  description = "agentgateway proxy data port reachable only from the Istio ingress Gateway"
  type        = number
}

variable "diagnostic_namespace" {
  default     = "istio-test"
  description = "Namespace containing the diagnostic Service"
  type        = string
}

variable "diagnostic_service" {
  default     = "istio-test"
  description = "Diagnostic Service name"
  type        = string
}

variable "diagnostic_service_port" {
  default     = 8080
  description = "Diagnostic Service HTTP port"
  type        = number
}

variable "gateway_name" {
  default     = "agentgateway-proxy"
  description = "agentgateway Gateway name"
  type        = string
}

variable "hostname" {
  default     = "agentgateway.localhost"
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

variable "istio_ingress_principal" {
  default     = "cluster.local/ns/istio-ingress/sa/gateway-istio"
  description = "Istio principal allowed to reach the agentgateway admin and data ports"
  type        = string
}

variable "namespace" {
  description = "Namespace containing agentgateway"
  type        = string
}
