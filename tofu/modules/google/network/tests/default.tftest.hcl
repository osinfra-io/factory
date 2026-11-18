# Test
# https://opentofu.org/docs/cli/commands/test

# Mock Providers
# https://opentofu.org/docs/cli/commands/test/#the-mock_provider-blocks

mock_provider "google" {}

run "default" {
  command = apply

  module {
    source = "./tests/fixtures/default"
  }

  # Example assertion

  assert {
    condition     = module.test.name == "mock-vpc"
    error_message = "The VPC name does not match the expected value 'mock-vpc'."
  }
}

run "dns" {
  command = apply

  module {
    source = "./tests/fixtures/default/dns"
  }
}

run "regional" {
  command = apply

  module {
    source = "./tests/fixtures/default/regional"
  }
}

run "regional_flow_logs" {
  command = plan

  module {
    source = "./regional"
  }

  variables {
    ip_cidr_range = "10.0.0.0/24"
    name          = "mock-subnet"
    network       = "mock-vpc"
    project       = "mock-project"
  }

  assert {
    condition     = length(google_compute_subnetwork.this.log_config) == 1
    error_message = "Ordinary subnetworks must keep VPC Flow Logs enabled."
  }
}

run "regional_proxy_only_subnet" {
  command = plan

  module {
    source = "./regional"
  }

  variables {
    ip_cidr_range = "10.0.0.0/24"
    name          = "mock-proxy-subnet"
    network       = "mock-vpc"
    project       = "mock-project"
    purpose       = "REGIONAL_MANAGED_PROXY"
  }

  assert {
    condition     = length(google_compute_subnetwork.this.log_config) == 0
    error_message = "Proxy-only subnetworks must not enable VPC Flow Logs."
  }
}

run "regional_nat" {
  command = apply

  module {
    source = "./tests/fixtures/default/regional_nat"
  }
}

variables {
  project = "mock-project"
}
