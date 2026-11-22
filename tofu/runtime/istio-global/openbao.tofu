# OpenBao has a dedicated global multi-cluster ingress, separate from the Istio mesh gateway.

resource "google_compute_global_address" "openbao_mci" {
  name    = "openbao-mci"
  project = local.assembly.workload_projects[var.team].id
}

resource "google_compute_managed_ssl_certificate" "openbao_mci" {
  name    = "openbao-mci"
  project = local.assembly.workload_projects[var.team].id

  managed {
    domains = [local.openbao_hostname]
  }
}

resource "google_dns_record_set" "openbao_mci" {
  managed_zone = local.environment_zone_name
  name         = "${local.openbao_hostname}."
  project      = local.assembly.shared_vpc.host_project_id
  rrdatas      = [google_compute_global_address.openbao_mci.address]
  ttl          = 300
  type         = "A"
}

# CryptoKeys and KeyRings cannot be deleted from Google Cloud. Losing the key means losing every
# secret stored in OpenBao, so destruction is blocked.

resource "google_kms_key_ring" "openbao_unseal" {
  lifecycle {
    prevent_destroy = true
  }

  # The multi-region location lets OpenBao clusters in every region use the same key.
  location = "us"
  name     = "openbao-unseal"
  project  = local.assembly.workload_projects[var.team].id
}

resource "google_kms_crypto_key" "openbao_unseal" {
  lifecycle {
    prevent_destroy = true
  }

  key_ring        = google_kms_key_ring.openbao_unseal.id
  name            = "unseal"
  rotation_period = "7776000s"
}

resource "google_kms_crypto_key_iam_member" "openbao_unseal" {
  crypto_key_id = google_kms_crypto_key.openbao_unseal.id
  member        = local.openbao_kms_member
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
}

resource "google_kms_crypto_key_iam_member" "openbao_unseal_viewer" {
  crypto_key_id = google_kms_crypto_key.openbao_unseal.id
  member        = local.openbao_kms_member
  role          = "roles/cloudkms.viewer"
}

# The OpenBao pods impersonate this account through GKE Workload Identity to auto-unseal.
resource "google_service_account" "openbao_kms" {
  account_id   = "openbao-kms"
  display_name = "OpenBao KMS Auto-Unseal"
  project      = local.assembly.workload_projects[var.team].id
}

resource "google_service_account_iam_member" "openbao_kms_workload_identity" {
  member             = local.openbao_workload_identity_member
  role               = "roles/iam.workloadIdentityUser"
  service_account_id = google_service_account.openbao_kms.name
}
