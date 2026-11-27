# Input Variables
# https://opentofu.org/docs/language/values/variables

variable "fixture_namespace" {
  default     = "floor-fixture"
  description = "Namespace holding the floor fixture Terraform objects and the runner environment secret"
  type        = string
}

variable "flux_distribution_version" {
  default     = "2.10.x"
  description = "Flux distribution version range installed by the Flux Operator"
  type        = string
}

variable "flux_operator_chart_version" {
  default     = "0.62.1"
  description = "Flux Operator Helm chart version"
  type        = string
}

variable "tofu_controller_chart_version" {
  default     = "0.16.6"
  description = "tofu-controller Helm chart version"
  type        = string
}

variable "tofu_controller_runner_image_tag" {
  default     = "v0.16.6"
  description = "tofu-controller runner image tag, pinned to the chart default rather than tracking the chart appVersion"
  type        = string
}
