terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.13.0"
    }
  }
}

# The token comes from VAULT_TOKEN in the runner environment (the floor-openbao-auth secret).
provider "vault" {
  address = local.openbao_address
}
