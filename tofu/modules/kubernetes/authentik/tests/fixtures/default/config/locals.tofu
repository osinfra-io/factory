locals {
  browser_group_policy_binding_count_output = length(module.test.browser_policy_bindings)

  preserved_authentication_source_output = contains(module.test.default_authentication_source_uuids, "00000000-0000-0000-0000-000000000013")
}
