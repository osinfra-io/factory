# Local Values
# https://opentofu.org/docs/language/values/locals

# The branch planner reads its watched resources as a YAML list string, and the
# tofu-controller chart values are assembled here rather than inline.

locals {
  branch_planner_resources = "- namespace: ${var.fixture_namespace}\n"

  helm_release_tofu_controller_values = [yamlencode(local.tofu_controller_values)]

  tofu_controller_values = {
    branchPlanner = {
      enabled = true
    }
    runner = {
      image = {
        tag = var.tofu_controller_runner_image_tag
      }
      serviceAccount = {
        allowedNamespaces = [var.fixture_namespace]
      }
    }
  }
}
