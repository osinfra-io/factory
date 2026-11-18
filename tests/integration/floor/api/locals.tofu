# Local Values
# https://opentofu.org/docs/language/values/locals

# The selector is shared by the Deployment and the Service.

locals {
  additional_namespaces = join(",", sort(tolist(var.additional_namespaces)))

  # Rolling the pods is the only way a changed token reaches the running process.
  pod_annotations = {
    "checksum/github-token" = var.github_token_checksum
  }

  selector_labels = {
    "app.kubernetes.io/name" = "floor-api"
  }
}
