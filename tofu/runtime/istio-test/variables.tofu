variable "image_version" {
  default     = "v0.4.4"
  description = "istio-test image tag"
  type        = string
}

variable "replicas" {
  default     = 1
  description = "Number of istio-test replicas"
  type        = number
}
