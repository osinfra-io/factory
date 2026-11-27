# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  environment_folder = local.environment_folders[module.core_helpers.environment]

  # Existing environment root folders; this root never creates or owns them.
  environment_folders = {
    non-production = { id = "851025769053", title = "Non-Production" }
    production     = { id = "1093631952702", title = "Production" }
    sandbox        = { id = "567188438944", title = "Sandbox" }
  }

  google_project_bootstrap_name = "${local.environment_folder.title} bootstrap"

  project_id = "bootstrap-${local.environment_folder.id}-${module.core_helpers.env}"

  runner_service_account_emails = {
    for team, account in google_service_account.runners : team => account.email
  }

  runner_service_accounts = {
    assembly = {
      account_id   = "assembly-floor-${module.core_helpers.env}"
      description  = "${local.environment_folder.title} Assembly floor identity and shared billing/state group membership manager"
      display_name = "${local.environment_folder.title} Assembly floor runner"
    }
    runtime = {
      account_id   = "runtime-floor-${module.core_helpers.env}"
      description  = "${local.environment_folder.title} Runtime floor identity and GKE security group membership manager"
      display_name = "${local.environment_folder.title} Runtime floor runner"
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
