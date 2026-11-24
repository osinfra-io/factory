# The built-in brand ships as the default; managing it lets the osinfra.io brand take over.
import {
  id = data.authentik_brand.built_in.id
  to = module.authentik_config.authentik_brand.built_in
}

# The embedded outpost ships with authentik and serves forward-auth from the regional server pods.
import {
  id = data.authentik_outpost.embedded.id
  to = module.authentik_regional_config.authentik_outpost.embedded
}

# The default authentication flow's identification stage is built into every authentik instance.
import {
  id = data.authentik_stage.default_authentication.id
  to = module.authentik_config.authentik_stage_identification.default_authentication
}
