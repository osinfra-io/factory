teams = {
  factory = {
    display_name = "Factory"

    authentik_groups = {
      agentgateway-admins = {
        description = "Access to the Factory agentgateway applications"
        label       = "agentgateway Admins"
        members = {
          non-production = ["brett@osinfra.io"]
          production     = ["brett@osinfra.io"]
          sandbox        = ["brett@osinfra.io"]
        }
      }
      authentik-admins = {
        description = "Factory authentik administrator access"
        label       = "Authentik Admins"
        members = {
          non-production = ["brett@osinfra.io"]
          production     = ["brett@osinfra.io"]
          sandbox        = ["brett@osinfra.io"]
        }
      }
      floor-approvers = {
        description = "Approve Factory Floor plans"
        label       = "Floor Approvers"
        members = {
          non-production = ["brett@osinfra.io"]
          production     = ["brett@osinfra.io"]
          sandbox        = ["brett@osinfra.io"]
        }
      }
      kagent-admins = {
        description = "Access to the Factory kagent application"
        label       = "kagent Admins"
        members = {
          non-production = ["brett@osinfra.io"]
          production     = ["brett@osinfra.io"]
          sandbox        = ["brett@osinfra.io"]
        }
      }
      openbao-secret-admins = {
        description = "Manage Factory OpenBao secrets and versions"
        label       = "OpenBao Secret Admins"
        members = {
          non-production = ["brett@osinfra.io"]
          production     = ["brett@osinfra.io"]
          sandbox        = ["brett@osinfra.io"]
        }
      }
      openbao-secret-readers = {
        description = "Read Factory OpenBao secrets"
        label       = "OpenBao Secret Readers"
        members = {
          non-production = ["brett@osinfra.io"]
          production     = ["brett@osinfra.io"]
          sandbox        = ["brett@osinfra.io"]
        }
      }
      openbao-secret-writers = {
        description = "Create and update Factory OpenBao secrets"
        label       = "OpenBao Secret Writers"
        members = {
          non-production = ["brett@osinfra.io"]
          production     = ["brett@osinfra.io"]
          sandbox        = ["brett@osinfra.io"]
        }
      }
    }

    google_basic_groups_env_memberships = {
      admin = {
        non-production = {
          managers = []
          members  = []
          owners   = ["brett@osinfra.io"]
        }
        production = {
          managers = []
          members  = []
          owners   = ["brett@osinfra.io"]
        }
        sandbox = {
          managers = []
          members  = []
          owners   = ["brett@osinfra.io"]
        }
      }
      reader = {
        non-production = {
          managers = []
          members  = []
          owners   = ["brett@osinfra.io"]
        }
        production = {
          managers = []
          members  = []
          owners   = ["brett@osinfra.io"]
        }
        sandbox = {
          managers = []
          members  = []
          owners   = ["brett@osinfra.io"]
        }
      }
      writer = {
        non-production = {
          managers = []
          members  = []
          owners   = ["brett@osinfra.io"]
        }
        production = {
          managers = []
          members  = []
          owners   = ["brett@osinfra.io"]
        }
        sandbox = {
          managers = []
          members  = []
          owners   = ["brett@osinfra.io"]
        }
      }
    }

    workload_project = {
      cloud_sql = {
        authentik = {
          database_version = "POSTGRES_16"
          machine_tier     = "db-custom-1-3840"
          regions          = ["us-east1"]
        }
      }

      kubernetes_engine = {
        artifact_registry_groups_memberships = {
          readers = {
            managers = []
            members  = []
            owners   = ["brett@osinfra.io"]
          }
          writers = {
            managers = []
            members  = []
            owners   = ["brett@osinfra.io"]
          }
        }

        dns_subdomain = "factory"

        locations = {
          us-east1-b = {
            subnet = {
              ip_cidr_range          = "10.60.0.0/20"
              master_ipv4_cidr_block = "10.63.192.0/28"
              pod_ip_cidr_range      = "10.0.0.0/15"
              services_ip_cidr_range = "10.61.224.0/20"
            }
          }
          us-east1-c = {
            subnet = {
              ip_cidr_range          = "10.60.16.0/20"
              master_ipv4_cidr_block = "10.63.192.16/28"
              pod_ip_cidr_range      = "10.2.0.0/15"
              services_ip_cidr_range = "10.61.240.0/20"
            }
          }
          us-east1-d = {
            subnet = {
              ip_cidr_range          = "10.60.32.0/20"
              master_ipv4_cidr_block = "10.63.192.32/28"
              pod_ip_cidr_range      = "10.4.0.0/15"
              services_ip_cidr_range = "10.62.0.0/20"
            }
          }
          us-east4-a = {
            subnet = {
              ip_cidr_range          = "10.60.48.0/20"
              master_ipv4_cidr_block = "10.63.192.48/28"
              pod_ip_cidr_range      = "10.6.0.0/15"
              services_ip_cidr_range = "10.62.16.0/20"
            }
          }
          us-east4-b = {
            subnet = {
              ip_cidr_range          = "10.60.64.0/20"
              master_ipv4_cidr_block = "10.63.192.64/28"
              pod_ip_cidr_range      = "10.8.0.0/15"
              services_ip_cidr_range = "10.62.32.0/20"
            }
          }
          us-east4-c = {
            subnet = {
              ip_cidr_range          = "10.60.80.0/20"
              master_ipv4_cidr_block = "10.63.192.80/28"
              pod_ip_cidr_range      = "10.10.0.0/15"
              services_ip_cidr_range = "10.62.48.0/20"
            }
          }
        }

        namespaces = {
          istio-test = {
            mesh_enabled = true

            route_auth_policies = {
              istio-test = {
                mode = "browser"

                public_paths = [
                  "/istio-test/health",
                  "/istio-test/metadata/*"
                ]

                required_groups = ["all"]
              }
            }

            routes = {
              istio-test = {
                path    = "/istio-test"
                port    = 8080
                service = "istio-test"
              }
            }
          }
        }
      }
    }
  }
}
