data "google_logging_project_cmek_settings" "this" {
  depends_on = [google_project_service.this]

  lifecycle {
    enabled = local.cis_2_2_logging_sink_local
  }

  project = google_project.this.project_id
}
