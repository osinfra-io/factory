# Test
# https://opentofu.org/docs/cli/commands/test

mock_provider "google" {
  mock_data "google_service_account" {
    defaults = {
      email = "mock-workload-identity@mock.iam.gserviceaccount.com"
    }
  }
}

mock_provider "kubernetes" {}

run "namespace_annotations" {
  command = apply

  variables {
    namespaces = {
      namespace-a = {
        annotations = {
          "example.com/managed-by" = "factory"
        }
        google_service_account = "mock-admin@mock.iam.gserviceaccount.com"
      }
    }

    workload_identity_service_account_emails = {
      namespace-a = "mock-workload-identity@mock.iam.gserviceaccount.com"
    }
  }

  assert {
    condition     = kubernetes_namespace_v1.this["namespace-a"].metadata[0].annotations["example.com/managed-by"] == "factory"
    error_message = "Namespace annotations must be applied from the namespace input."
  }
}
