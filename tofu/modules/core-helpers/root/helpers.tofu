# Factory Core Helpers Module
# https://github.com/osinfra-io/factory

module "workspace" {
  source = "../child"

  workspace = var.workspace
}
