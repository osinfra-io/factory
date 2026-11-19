billing_account_id = "01C550-A2C86B-B8F16B"
environment        = "sandbox"
host_project_team  = "factory"

cluster_subnets = {
  factory = {
    us-east1-b = {
      control_plane = "10.80.16.0/28"
      nodes         = "10.80.0.0/20"
      pods          = "10.81.0.0/16"
      services      = "10.82.0.0/20"
    }
  }
}

private_service_range = "172.16.0.0/16"
