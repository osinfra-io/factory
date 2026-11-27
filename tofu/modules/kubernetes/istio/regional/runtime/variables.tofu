# Input Variables
# https://opentofu.org/docs/language/values/variables

variable "ca_address" {
  default     = "cert-manager-istio-csr.cert-manager.svc:443"
  description = "The certificate authority address for workload certificates; null uses Istio's built-in CA"
  type        = string
}

variable "chart_repository" {
  default     = "https://blob.istio.io/istio-release/charts"
  description = "The repository to pull the Istio Helm charts from"
  type        = string
}

variable "cluster_name" {
  description = "The Istio cluster name"
  type        = string
}

variable "cni_cpu_limits" {
  default     = null
  description = "The CPU limit for the Istio CNI node agent"
  type        = string
}

variable "cni_cpu_requests" {
  description = "The CPU request for the Istio CNI node agent"
  type        = string
}

variable "cni_memory_limits" {
  default     = null
  description = "The memory limit for the Istio CNI node agent"
  type        = string
}

variable "cni_memory_requests" {
  description = "The memory request for the Istio CNI node agent"
  type        = string
}

variable "cni_platform" {
  description = "Istio CNI platform profile; empty leaves the upstream Kind-compatible profile selected"
  type        = string
}

variable "enable_ca_server" {
  default     = false
  description = "Whether istiod serves workload certificates using its built-in CA"
  type        = bool
}

variable "enable_multi_network" {
  default     = true
  description = "Enable Istio ambient multi-network control plane settings"
  type        = bool
}

variable "image_hub" {
  description = "Image registry hub used by Istio charts"
  type        = string
}

variable "mesh_config_extension_providers" {
  default     = []
  description = "Istio meshConfig extensionProviders entries"
  type        = list(any)
}

variable "mesh_config_service_settings" {
  default     = []
  description = "Istio meshConfig serviceSettings entries"
  type        = list(any)
}

variable "network" {
  description = "The Istio network name"
  type        = string
}

variable "pilot_autoscale_max" {
  description = "The maximum number of Istio pilot replicas"
  type        = number
}

variable "pilot_autoscale_min" {
  description = "The minimum number of Istio pilot replicas"
  type        = number
}

variable "pilot_cpu_limits" {
  description = "The CPU limit for istiod"
  type        = string
}

variable "pilot_cpu_requests" {
  description = "The CPU request for istiod"
  type        = string
}

variable "pilot_memory_limits" {
  description = "The memory limit for istiod"
  type        = string
}

variable "pilot_memory_requests" {
  description = "The memory request for istiod"
  type        = string
}

variable "pilot_replica_count" {
  description = "The number of Istio pilot replicas"
  type        = number
}

variable "proxy_cpu_limits" {
  description = "The CPU limit for the Istio proxy"
  type        = string
}

variable "proxy_cpu_requests" {
  description = "The CPU request for the Istio proxy"
  type        = string
}

variable "proxy_memory_limits" {
  description = "The memory limit for the Istio proxy"
  type        = string
}

variable "proxy_memory_requests" {
  description = "The memory request for the Istio proxy"
  type        = string
}

variable "ztunnel_cpu_limits" {
  description = "The CPU limit for ztunnel"
  type        = string
}

variable "ztunnel_cpu_requests" {
  description = "The CPU request for ztunnel"
  type        = string
}

variable "ztunnel_memory_limits" {
  description = "The memory limit for ztunnel"
  type        = string
}

variable "ztunnel_memory_requests" {
  description = "The memory request for ztunnel"
  type        = string
}
