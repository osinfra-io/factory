# Input Variables
# https://opentofu.org/docs/language/values/variables

variable "approver_emails" {
  default     = []
  description = "Email addresses of signed-in users who are added to the approver group for local testing"
  type        = list(string)
}

variable "approver_group" {
  default     = "fixture: Floor Verification Approvers"
  description = "authentik group whose members may approve plans through floor-api"
  type        = string
}

variable "authentik_token" {
  description = "authentik bootstrap token used to manage the verification identity"
  sensitive   = true
  type        = string
}

variable "authentik_url" {
  description = "authentik admin API URL, reached over a loopback forward because the provider cannot resolve .localhost"
  type        = string
}

variable "token_file" {
  description = "Path the generated app password for the verification user is written to"
  type        = string
}

variable "username" {
  default     = "floor-verify"
  description = "Username of the local verification identity"
  type        = string
}

variable "visitor_token_file" {
  description = "Path the generated app password for the visitor identity is written to"
  type        = string
}

variable "visitor_username" {
  default     = "floor-visitor"
  description = "Username of the local identity that authenticates without the approver group"
  type        = string
}
