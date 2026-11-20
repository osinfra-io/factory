# Input Variables
# https://opentofu.org/docs/language/values/variables

variable "billing_account_id" {
  default     = "01C550-A2C86B-B8F16B"
  description = "Existing billing account used by Foundation and Assembly"
  type        = string

  validation {
    condition     = can(regex("^[A-Z0-9]{6}-[A-Z0-9]{6}-[A-Z0-9]{6}$", var.billing_account_id))
    error_message = "Provide a billing account ID in XXXXXX-XXXXXX-XXXXXX format."
  }
}
