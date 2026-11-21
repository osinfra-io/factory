# Shared root of trust for every cluster in the environment, kept outside the
# per-zone stages so the CA survives Runtime teardown and all clusters share it.

resource "tls_private_key" "cert_manager_ca" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_self_signed_cert" "cert_manager_ca" {
  allowed_uses = [
    "cert_signing",
    "digital_signature",
    "key_encipherment",
  ]

  is_ca_certificate = true
  private_key_pem   = tls_private_key.cert_manager_ca.private_key_pem

  subject {
    common_name  = "factory-self-signed-ca.osinfra.io"
    organization = "Factory Self-Signed CA"
  }

  validity_period_hours = 262980 # 30 years
}
