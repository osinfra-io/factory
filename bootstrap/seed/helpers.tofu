# Factory Core Helpers Module
# https://github.com/osinfra-io/factory

module "core_helpers" {
  source = "../../tofu/modules/core-helpers/root"

  cost_center         = "x001"
  data_classification = "public"
  repository          = "factory"
  team                = "factory"
}
