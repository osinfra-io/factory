variable "bucket" {
  description = "GCS bucket containing the environment's Assembly state"
  type        = string
}

variable "node_pool" {
  default = {
    disk_size_gb   = 100
    disk_type      = "pd-balanced"
    image_type     = "COS_CONTAINERD"
    machine_type   = "e2-standard-4"
    max_node_count = 2
    min_node_count = 1
    node_count     = 1
  }
  description = "Default node pool created in each cluster"
  type = object({
    disk_size_gb   = number
    disk_type      = string
    image_type     = string
    machine_type   = string
    max_node_count = number
    min_node_count = number
    node_count     = number
  })
}

variable "regions" {
  default     = ["us-east1", "us-east4"]
  description = "Regions whose clusters the fleet host cluster registers as fleet members"
  type        = list(string)
}

variable "runtime_enabled" {
  default     = true
  description = "Whether this workspace's cluster exists; set to false to destroy it"
  type        = bool
}
