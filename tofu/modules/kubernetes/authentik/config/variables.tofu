# Input Variables
# https://opentofu.org/docs/language/values/variables

variable "application_groups" {
  default     = {}
  description = "Team-owned application access groups keyed by stable team/group identifiers. Names include the team key, for example factory: agentgateway Admins. Members are lowercase verified Google emails for the current environment."
  type = map(object({
    description = string
    members     = list(string)
    name        = string
  }))

  validation {
    condition = alltrue([
      for group in values(var.application_groups) :
      can(regex("^[a-z0-9]+(-[a-z0-9]+)*: [A-Za-z][A-Za-z0-9]*( [A-Za-z0-9]+)*$", group.name)) &&
      length(trimspace(group.description)) > 0 &&
      length(distinct(group.members)) == length(group.members) &&
      alltrue([
        for email in group.members : can(regex("^[a-z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-z0-9-]+(\\.[a-z0-9-]+)+$", email))
      ])
    ]) && length(distinct([for group in values(var.application_groups) : group.name])) == length(var.application_groups)

    error_message = "Application groups must have unique team-qualified names, non-blank descriptions, and unique lowercase member emails."
  }

  validation {
    condition = length(var.application_groups) == 0 || local.google_oauth_enabled

    error_message = "Managed application groups require the existing Google OAuth source to be enabled."
  }
}

variable "application_launch_url" {
  default     = null
  description = "Optional URL shown as the launch link for the authentik application"
  nullable    = true
  type        = string
}

variable "application_name" {
  default     = "Istio Gateway"
  description = "The display name of the authentik application for the gateway"
  type        = string
}

variable "application_slug" {
  default     = "gateway"
  description = "The slug of the authentik application, used in the OIDC issuer URL"
  type        = string
}

variable "authentik_url" {
  description = "The public base URL of the authentik deployment, used to construct the OIDC issuer and JWKS URLs"
  type        = string

  validation {
    condition     = startswith(var.authentik_url, "https://")
    error_message = "The authentik_url must be a public HTTPS URL (starting with https://)."
  }
}

variable "authorization_flow_slug" {
  default     = "default-provider-authorization-implicit-consent"
  description = "The slug of the authentik authorization flow to use for the providers"
  type        = string
}

variable "branding" {
  default     = null
  description = "Optional branded login configuration; null leaves authentik's existing brand and authentication flow unchanged"
  nullable    = true
  type = object({
    domain     = string
    flow_title = string
    title      = string
  })

  validation {
    condition = var.branding == null ? true : (
      length(trimspace(var.branding.domain)) > 0 &&
      length(trimspace(var.branding.flow_title)) > 0 &&
      length(trimspace(var.branding.title)) > 0
    )
    error_message = "Branding domain, title, and flow_title must be non-empty when branding is configured."
  }
}

variable "browser_group_policy_bindings" {
  default     = {}
  description = "Per-host browser authorization. Groups and roles each use OR, with AND between the lists; roles are authentik group names. Team-qualified requirements additionally require an active, Google-linked verified identity."
  type = map(object({
    groups      = optional(list(string), [])
    hidden      = optional(bool, false)
    host        = string
    icon        = optional(string)
    launch_url  = optional(string)
    name        = optional(string)
    policy_name = optional(string)
    roles       = optional(list(string), [])
  }))

  validation {
    condition = alltrue([
      for binding in values(var.browser_group_policy_bindings) :
      can(regex("^https://[^/]+$", binding.host)) &&
      length(concat(binding.groups, binding.roles)) > 0 &&
      length(distinct(binding.groups)) == length(binding.groups) &&
      length(distinct(binding.roles)) == length(binding.roles) && alltrue([
        for group in concat(binding.groups, binding.roles) : length(trimspace(group)) > 0
      ])
    ])
    error_message = "Each browser binding must declare an HTTPS origin and at least one group or role, with no empty names or duplicates within either list."
  }

  validation {
    condition = alltrue([
      for binding in values(var.browser_group_policy_bindings) :
      binding.policy_name == null || can(regex("^[a-z0-9]+(-[a-z0-9]+)*$", binding.policy_name))
    ])
    error_message = "A browser binding policy_name must be lowercase kebab-case."
  }

  validation {
    condition = alltrue([
      for a in values(var.browser_group_policy_bindings) : alltrue([
        for b in values(var.browser_group_policy_bindings) :
        coalesce(a.policy_name, "${lower(replace(replace(trimprefix(a.host, "https://"), ".", "-"), "_", "-"))}-browser-access") != coalesce(b.policy_name, "${lower(replace(replace(trimprefix(b.host, "https://"), ".", "-"), "_", "-"))}-browser-access") ||
        (toset(a.groups) == toset(b.groups) && toset(a.roles) == toset(b.roles))
      ])
    ])
    error_message = "Browser bindings that resolve to the same policy name, explicit or generated, must declare identical groups and roles."
  }
}

variable "cli_oidc_browser_keys" {
  default     = []
  description = "Keys of browser_group_policy_bindings whose proxy providers accept bearer tokens from the Factory CLI OIDC provider. The provider and application are created only when this is not empty."
  type        = set(string)

  validation {
    condition     = alltrue([for key in var.cli_oidc_browser_keys : contains(keys(var.browser_group_policy_bindings), key)])
    error_message = "Every cli_oidc_browser_keys entry must be a key of browser_group_policy_bindings."
  }
}

variable "client_id" {
  default     = "gateway"
  description = "The OAuth2 client ID for the gateway OIDC provider"
  type        = string
}

variable "default_authentication_source_uuids" {
  default     = []
  description = "UUIDs of existing sources assigned to the shared default authentication identification stage; preserved when the optional Google source is added"
  type        = list(string)

  validation {
    condition = length(distinct(var.default_authentication_source_uuids)) == length(var.default_authentication_source_uuids)

    error_message = "The default_authentication_source_uuids list must not contain duplicates."
  }
}

variable "default_authentication_stage_settings" {
  default = {
    captcha_stage             = null
    case_insensitive_matching = true
    enable_remember_me        = false
    enrollment_flow           = null
    password_stage            = null
    passwordless_flow         = null
    pretend_user_exists       = true
    recovery_flow             = null
    show_matched_user         = true
    show_source_labels        = false
    user_fields               = ["email", "username"]
    webauthn_stage            = null
  }
  description = "Complete existing configuration of the shared default authentication identification stage, including explicit null values for unlinked stages and flows"
  type = object({
    captcha_stage             = string
    case_insensitive_matching = bool
    enable_remember_me        = bool
    enrollment_flow           = string
    password_stage            = string
    passwordless_flow         = string
    pretend_user_exists       = bool
    recovery_flow             = string
    show_matched_user         = bool
    show_source_labels        = bool
    user_fields               = list(string)
    webauthn_stage            = string
  })

  validation {
    condition = length(var.default_authentication_stage_settings.user_fields) > 0

    error_message = "The default_authentication_stage_settings user_fields list must not be empty."
  }
}

variable "gateway_oidc_enabled" {
  default     = true
  description = "Create the gateway OIDC application and provider independently of browser forward-auth applications."
  type        = bool
}

variable "google_internal_domains" {
  default     = []
  description = "Google Workspace domains whose verified users are classified as internal; other Google users remain external."
  type        = set(string)

  validation {
    condition = alltrue([
      for domain in var.google_internal_domains :
      can(regex("^[a-z0-9-]+(\\.[a-z0-9-]+)+$", domain))
    ])
    error_message = "Google internal domains must be lowercase DNS domain names without a scheme or path."
  }
}

variable "google_oauth_client_id" {
  default     = ""
  description = "The OAuth client ID for the optional Google source in authentik; leave empty to disable the source."
  type        = string
}

variable "google_oauth_client_secret" {
  default     = ""
  description = "The OAuth client secret for the optional Google source in authentik; leave empty to disable the source."
  sensitive   = true
  type        = string
}

variable "invalidation_flow_slug" {
  default     = "default-provider-invalidation-flow"
  description = "The slug of the authentik invalidation flow to use for the providers"
  type        = string
}

variable "manage_default_authentication_stage" {
  default     = false
  description = "Whether to manage the imported shared default authentication identification stage; keep true while disabling Google, then remove the state address before setting false"
  type        = bool

  validation {
    condition = var.google_oauth_client_id == "" || var.google_oauth_client_secret == "" || var.manage_default_authentication_stage

    error_message = "manage_default_authentication_stage must be true when Google OAuth credentials are configured."
  }
}

variable "openbao_application_icon" {
  default     = null
  description = "Optional icon URL for the OpenBao application."
  type        = string
}

variable "openbao_hostname" {
  default     = null
  description = "The canonical OpenBao hostname used to register the OpenBao UI OIDC callback; null disables the dedicated OpenBao application"
  nullable    = true
  type        = string

  validation {
    condition     = var.openbao_hostname == null ? true : can(regex("^[a-z0-9-]+(\\.[a-z0-9-]+)+$", var.openbao_hostname))
    error_message = "The openbao_hostname must be a lowercase DNS hostname without a scheme, path, or trailing dot."
  }
}

variable "redirect_uris" {
  default     = []
  description = "The list of allowed OAuth2 redirect URIs for the gateway OIDC provider"

  type = list(object({
    matching_mode     = string
    redirect_uri_type = optional(string, "authorization")
    url               = string
  }))
}

variable "signing_key_name" {
  default     = "authentik Self-signed Certificate"
  description = "The name of the authentik certificate-key pair used to sign OIDC tokens"
  type        = string
}

variable "superuser_group_keys" {
  default     = []
  description = "Keys in application_groups whose memberships receive authentik-wide superuser permissions."
  type        = set(string)

  validation {
    condition = length(setsubtract(var.superuser_group_keys, toset(keys(var.application_groups)))) == 0

    error_message = "Every superuser_group_keys entry must identify a declared application group."
  }

  validation {
    condition = length(var.superuser_group_keys) == 0 || local.google_oauth_enabled

    error_message = "authentik superuser groups require the existing Google OAuth source to be enabled."
  }
}
