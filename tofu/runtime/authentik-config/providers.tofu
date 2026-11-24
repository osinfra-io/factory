terraform {
  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = "~> 2026.8.0"
    }
  }
}

# The provider reaches authentik through its public hostname, so the gateway certificate must be active.
provider "authentik" {
  token = local.authentik_token
  url   = local.authentik_url
}
