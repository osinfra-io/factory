# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  project_id = "bootstrap-${var.sandbox_folder_id}-${module.core_helpers.env}"

  runner_service_account_emails = {
    for team, account in google_service_account.runners : team => account.email
  }

  runner_service_accounts = {
    assembly = {
      account_id   = "assembly-floor-${module.core_helpers.env}"
      description  = "Sandbox Assembly floor identity and shared billing/state group membership manager"
      display_name = "Sandbox Assembly floor runner"
    }
    runtime = {
      account_id   = "runtime-floor-${module.core_helpers.env}"
      description  = "Sandbox Runtime floor identity and GKE security group membership manager"
      display_name = "Sandbox Runtime floor runner"
    }
  }

  services = toset([
    "billingbudgets.googleapis.com",
    "cloudbilling.googleapis.com",
    "cloudidentity.googleapis.com",
    "cloudkms.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "serviceusage.googleapis.com",
    "storage.googleapis.com"
  ])

  state_bucket_name = "${local.project_id}-state"
}
