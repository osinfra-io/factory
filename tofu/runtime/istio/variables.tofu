variable "resources" {
  default = {
    cni_cpu_requests                  = "25m"
    cni_memory_requests               = "64Mi"
    east_west_gateway_cpu_limits      = "500m"
    east_west_gateway_cpu_requests    = "50m"
    east_west_gateway_memory_limits   = "256Mi"
    east_west_gateway_memory_requests = "64Mi"
    pilot_autoscale_max               = 1
    pilot_cpu_limits                  = "500m"
    pilot_cpu_requests                = "100m"
    pilot_memory_limits               = "256Mi"
    pilot_memory_requests             = "128Mi"
    ztunnel_cpu_requests              = "50m"
    ztunnel_memory_requests           = "128Mi"
  }
  description = "Istio data and control plane sizing; the defaults suit a single e2-standard-4 node per cluster"
  type        = map(any)
}
