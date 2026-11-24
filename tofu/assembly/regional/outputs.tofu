output "cloud_sql_instances" {
  description = "Private DNS names and instance connection references for regional Cloud SQL"
  value = {
    for key, instance in module.google_cloud_sql : key => {
      host               = google_dns_record_set.cloud_sql[key].name
      instance           = instance.instance
      private_ip_address = instance.private_ip_address
    }
  }
}

output "runtime_networks" {
  description = "Regional Shared VPC, workload project, and subnet references consumed by Runtime"
  value       = local.runtime_networks
}
