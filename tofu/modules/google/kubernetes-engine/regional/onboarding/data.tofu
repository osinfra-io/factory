# Google Service Account Data Source
# https://search.opentofu.org/provider/hashicorp/google/latest/docs/data-sources/service_account

data "google_service_account" "workload_identities" {
  for_each = var.namespaces

  account_id = var.workload_identity_service_account_emails[each.key]
}
