# Connection to this zone's Runtime cluster, shared by every in-cluster stage.
# Workspace names follow <zone>-<stage>-<environment>, for example us-east1-b-cert-manager-sandbox.

variable "bucket" {
  description = "GCS bucket containing the environment's Runtime and trust state"
  type        = string
}

variable "runtime_enabled" {
  default     = true
  description = "Whether this stage's resources exist; set to false to destroy them while the cluster is still reachable"
  type        = bool
}

data "google_client_config" "this" {}

data "terraform_remote_state" "cluster" {
  backend = "gcs"
  config = {
    bucket = var.bucket
    prefix = "runtime"
  }
  workspace = local.cluster_workspace

  lifecycle {
    precondition {
      condition     = local.workspace_valid
      error_message = "Use a zonal Runtime workspace such as us-east1-b-${local.stage}-sandbox."
    }
  }
}

locals {
  cluster = values(data.terraform_remote_state.cluster.outputs.clusters)[0]

  cluster_workspace = "${local.location}-runtime-${coalesce(module.core_helpers.environment, "unsupported")}"

  # A single instance key for modules that must disappear when the stage is disabled.
  instances = var.runtime_enabled ? toset(["this"]) : toset([])

  location = "${coalesce(module.core_helpers.region, "unsupported")}-${coalesce(module.core_helpers.zone, "x")}"

  workspace_valid = can(regex("^us-east[14]-[a-f]-${local.stage}-(sandbox|non-production|production)$", terraform.workspace))
}

provider "helm" {
  kubernetes = {
    cluster_ca_certificate = base64decode(local.cluster.ca_certificate)
    host                   = "https://${local.cluster.endpoint}"
    token                  = data.google_client_config.this.access_token
  }
}

provider "kubernetes" {
  cluster_ca_certificate = base64decode(local.cluster.ca_certificate)
  host                   = "https://${local.cluster.endpoint}"
  token                  = data.google_client_config.this.access_token
}
