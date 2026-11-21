output "cis_2_2_logging_bucket_locked" {
  description = "Whether the local CIS 2.2 logging bucket is locked, or null when logging is external"
  value       = module.google_project.cis_2_2_logging_bucket_locked
}
