# Input Variables
# https://opentofu.org/docs/language/values/variables

variable "billing_account" {
  description = "The alphanumeric ID of the billing account this project belongs to"
  type        = string
}

variable "budget_notification_email" {
  default     = "billing-admins@osinfra.io"
  description = "The email address to send budget notifications to"
  type        = string
}

variable "cis_2_2_logging_bucket_locked" {
  default     = true
  description = "Boolean to enable CIS 2.2 logging bucket lock"
  type        = bool
}

variable "cis_2_2_logging_sink" {
  default     = null
  description = "External CIS 2.2 logging sink project; set the object when the project ID is unknown until apply"
  type = object({
    project_id = string
  })

  validation {
    condition = var.cis_2_2_logging_sink == null || var.cis_2_2_logging_sink_project_id == ""

    error_message = "Set either cis_2_2_logging_sink or cis_2_2_logging_sink_project_id, not both."
  }
}

variable "cis_2_2_logging_sink_project_id" {
  default     = ""
  description = "The CIS 2.2 logging sink project ID"
  type        = string
}

variable "deletion_policy" {
  default     = "PREVENT"
  description = "The deletion policy for the project"
  type        = string
}

variable "folder_id" {
  description = "The numeric ID of the folder this project should be created under. Only one of `org_id` or `folder_id` may be specified"
  type        = string
}

variable "key_ring_location" {
  default     = "us"
  description = "The location of the key ring to create"
  type        = string
}

variable "labels" {
  default     = {}
  description = "A map of key/value pairs to assign to the resources being created"
  type        = map(string)
}

variable "monthly_budget_amount" {
  default     = 5
  description = "The monthly budget amount in USD to set for the project"
  type        = number
}

variable "prefix" {
  default     = "test"
  description = "The team prefix for example: `ops` (Operations), `sec` (Security)"
  type        = string
}

variable "random_project_id" {
  default     = true
  description = "If true, a random hex value with a prefix of tf will be added to the `project_id`"
  type        = bool
}

variable "random_project_id_hex_length" {
  default     = 3
  description = "Number of random hexadecimal digits after tf in a generated project ID"
  type        = number

  validation {
    condition = var.random_project_id_hex_length >= 1 && var.random_project_id_hex_length <= 24 && floor(var.random_project_id_hex_length) == var.random_project_id_hex_length

    error_message = "The random project ID suffix length must be a whole number between 1 and 24."
  }
}

variable "security_notification_email" {
  default     = "security@osinfra.io"
  description = "The email address to send security notifications to"
  type        = string
}

variable "services" {
  default     = []
  description = "A list of services to enable in the project"
  type        = list(string)
}
