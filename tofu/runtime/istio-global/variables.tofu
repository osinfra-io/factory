variable "bucket" {
  description = "GCS bucket containing the environment's Assembly state"
  type        = string
}

variable "locations" {
  default     = ["us-east1-b", "us-east4-a"]
  description = "Zones that run a Runtime cluster in this environment"
  type        = list(string)
}

variable "team" {
  default     = "factory"
  description = "Team whose workload project and DNS zone host the Istio gateway"
  type        = string
}
