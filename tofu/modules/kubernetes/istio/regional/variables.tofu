# Input Variables
# https://opentofu.org/docs/language/values/variables

variable "artifact_registry" {
  default     = "us-docker.pkg.dev/plt-lz-services-tf79-prod/plt-docker-virtual"
  description = "The registry to pull the images from"
  type        = string
}

variable "chart_repository" {
  default     = "https://blob.istio.io/istio-release/charts"
  description = "The repository to pull the Istio Helm chart from"
  type        = string
}

variable "cluster_prefix" {
  description = "Prefix for your cluster name, region, and zone (if applicable) will be added to the end of the cluster name"
  type        = string
}

variable "cni_cpu_limits" {
  default     = null
  description = "The CPU limit for the Istio CNI node agent, unset by default to match the upstream chart which ships requests only"
  type        = string
}

variable "cni_cpu_requests" {
  default     = "100m"
  description = "The CPU request for the Istio CNI node agent"
  type        = string
}

variable "cni_memory_limits" {
  default     = null
  description = "The memory limit for the Istio CNI node agent, unset by default to match the upstream chart which ships requests only"
  type        = string
}

variable "cni_memory_requests" {
  default     = "100Mi"
  description = "The memory request for the Istio CNI node agent"
  type        = string
}

variable "east_west_gateway_cpu_limits" {
  default     = "2"
  description = "The CPU limit for the Istio east-west gateway"
  type        = string
}

variable "east_west_gateway_cpu_requests" {
  default     = "100m"
  description = "The CPU request for the Istio east-west gateway"
  type        = string
}

variable "east_west_gateway_memory_limits" {
  default     = "1Gi"
  description = "The memory limit for the Istio east-west gateway"
  type        = string
}

variable "east_west_gateway_memory_requests" {
  default     = "128Mi"
  description = "The memory request for the Istio east-west gateway"
  type        = string
}

variable "enable_istio_gateway" {
  default     = false
  description = "Enable the Istio gateway, used for ingress traffic into the mesh"
  type        = bool
}

variable "gateway_autoscale_max" {
  default     = 5
  description = "The maximum number of gateway replicas to run"
  type        = number
}

variable "gateway_autoscale_min" {
  default     = 1
  description = "The minimum number of gateway replicas to run"
  type        = number
}

variable "gateway_cpu_limits" {
  default     = "100m"
  description = "The CPU limit for the Istio gateway"
  type        = string
}

variable "gateway_cpu_requests" {
  default     = "25m"
  description = "The CPU request for the Istio gateway"
  type        = string
}

variable "gateway_dns" {
  default     = {}
  description = "Map of attributes for the Istio gateway domain names, it is also used to create the managed certificate resource"
  type = map(object({
    managed_zone = string
    project      = string
  }))
}

variable "gateway_mci_global_address" {
  default     = ""
  description = "The IP address for the Istio Gateway multi-cluster ingress"
  type        = string
}

variable "gateway_mci_ssl_certificate_names" {
  default     = []
  description = "The names of the pre-shared SSL certificates attached to the Istio Gateway multi-cluster ingress"
  type        = list(string)

  validation {
    condition = !var.enable_istio_gateway || length(var.gateway_mci_ssl_certificate_names) > 0

    error_message = "At least one SSL certificate name is required when enable_istio_gateway is true."
  }
}

variable "gateway_memory_limits" {
  default     = "64Mi"
  description = "The memory limit for the Istio gateway"
  type        = string
}

variable "gateway_memory_requests" {
  default     = "32Mi"
  description = "The memory request for the Istio gateway"
  type        = string
}


variable "labels" {
  default     = {}
  description = "A map of key/value pairs to assign to the resources being created"
  type        = map(string)
}

variable "mesh_config_extension_providers" {
  default     = []
  description = "Istio meshConfig extensionProviders entries (e.g. envoyExtAuthzHttp providers) merged into istiod's Helm values, keeping the mesh config fully rendered by Helm instead of patched out-of-band"
  type        = list(any)
}

variable "mesh_config_service_settings" {
  default     = []
  description = "Istio meshConfig serviceSettings entries (e.g. clusterLocal service scoping) merged into istiod's Helm values, keeping the mesh config fully rendered by Helm instead of patched out-of-band"
  type        = list(any)
}

variable "multi_cluster_service_clusters" {
  default     = []
  description = "List of clusters to be included in the MultiClusterService"
  type = list(object({
    link = string
  }))
}

variable "pilot_autoscale_max" {
  default     = 5
  description = "The maximum number of Istio pilot replicas to run"
  type        = number
}

variable "pilot_autoscale_min" {
  default     = 1
  description = "The minimum number of Istio pilot replicas to run"
  type        = number
}

variable "pilot_cpu_limits" {
  default     = "25m"
  description = "The CPU limit for the Istio pilot"
  type        = string
}

variable "pilot_cpu_requests" {
  default     = "10m"
  description = "The CPU request for the Istio pilot"
  type        = string
}

variable "pilot_memory_limits" {
  default     = "64Mi"
  description = "The memory limit for the Istio pilot"
  type        = string
}

variable "pilot_memory_requests" {
  default     = "32Mi"
  description = "The memory request for the Istio pilot"
  type        = string
}

variable "pilot_replica_count" {
  default     = 1
  description = "The number of Istio pilot replicas to run"
  type        = number
}

variable "project" {
  description = "The ID of the project in which the resource belongs"
  type        = string
}

variable "proxy_cpu_limits" {
  default     = "25m"
  description = "The CPU limit for the Istio proxy"
  type        = string
}

variable "proxy_cpu_requests" {
  default     = "10m"
  description = "The CPU request for the Istio proxy"
  type        = string
}

variable "proxy_memory_limits" {
  default     = "64Mi"
  description = "The memory limit for the Istio proxy"
  type        = string
}

variable "proxy_memory_requests" {
  default     = "32Mi"
  description = "The memory request for the Istio proxy"
  type        = string
}

variable "tls_self_signed_cert_cert_manager_root_cert" {
  description = "The self-signed certificate for the cert-manager root certificate"
  type        = string
}

variable "tls_self_signed_cert_cert_manager_root_key" {
  description = "The private key for the cert-manager root certificate"
  sensitive   = true
  type        = string
}

variable "ztunnel_cpu_limits" {
  default     = "500m"
  description = "The CPU limit for ztunnel"
  type        = string
}

variable "ztunnel_cpu_requests" {
  default     = "250m"
  description = "The CPU request for ztunnel"
  type        = string
}

variable "ztunnel_memory_limits" {
  default     = "512Mi"
  description = "The memory limit for ztunnel"
  type        = string
}

variable "ztunnel_memory_requests" {
  default     = "256Mi"
  description = "The memory request for ztunnel"
  type        = string
}
