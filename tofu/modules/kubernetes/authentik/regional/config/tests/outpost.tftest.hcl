mock_provider "authentik" {
  mock_resource "authentik_outpost" {
    defaults = {
      id = "mock-outpost"
    }
  }
}

run "regional_embedded_outpost" {
  command = apply

  variables {
    authentik_url      = "https://authentik.example.com"
    namespace          = "authentik"
    proxy_provider_ids = [2, 3]
  }

  assert {
    condition = (
      authentik_outpost.embedded.name == "authentik Embedded Outpost" &&
      authentik_outpost.embedded.protocol_providers == tolist([2, 3]) &&
      jsondecode(authentik_outpost.embedded.config).authentik_host == "https://authentik.example.com"
    )
    error_message = "The regional outpost must use the shared proxy providers and connect to the Authentik instance."
  }

  assert {
    condition = (
      output.outpost_namespace == "authentik" &&
      output.outpost_service_name == "authentik-server" &&
      output.outpost_service_port == 80
    )
    error_message = "Regional outpost service outputs must identify the local Authentik server."
  }
}
