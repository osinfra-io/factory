# This directory contains partial configurations shared by the Runtime stages.
locals {
  stage = "shared"

  terraform_remote_state_trust_workspace = "trust-${coalesce(module.core_helpers.environment, "unsupported")}"
}
