locals {
  logging_sink            = var.defer_logging_sink ? { project_id = terraform_data.logging_project.output } : null
  logging_sink_project_id = var.defer_logging_sink ? "" : var.cis_2_2_logging_sink_project_id
}
