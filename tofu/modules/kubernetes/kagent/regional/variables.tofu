# Input Variables
# https://opentofu.org/docs/language/values/variables

variable "chart_repository" {
  default     = "oci://ghcr.io/kagent-dev/kagent/helm"
  description = "OCI repository containing the kagent Helm charts"
  type        = string
}

variable "kagent_version" {
  default     = "1.0.1"
  description = "kagent Helm chart version"
  type        = string
}

variable "labels" {
  default     = {}
  description = "Labels applied to kagent resources"
  type        = map(string)
}

variable "llm_base_url" {
  default     = null
  description = "Base URL for the default OpenAI-compatible model, e.g. the internal agentgateway proxy; null calls the provider directly"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for kagent"
  type        = string
}

variable "postgres_owner_secret_name" {
  default     = "kagent-postgres-owner"
  description = "Existing Secret whose ownerConnectionString key holds the PostgreSQL owner connection string; the owner creates the schema and runs migrations"
  type        = string
}

variable "postgres_read_write_secret_name" {
  default     = "kagent-postgres-readwrite"
  description = "Existing Secret whose readWriteConnectionString key holds the PostgreSQL read/write connection string used for runtime queries"
  type        = string
}

variable "substrate_namespace" {
  description = "Kubernetes namespace where Agent Substrate is installed"
  type        = string
}

variable "substrate_version" {
  default     = "1.0.1"
  description = "Agent Substrate version, used to select the matching worker image tag"
  type        = string
}

variable "worker_image_repository" {
  default     = "ghcr.io/kagent-dev/substrate/ateworker-gvisor"
  description = "Agent Substrate gVisor worker image repository, without a tag"
  type        = string
}

variable "worker_pool_replicas" {
  default     = 1
  description = "Number of Agent Substrate workers; each long-lived harness pins one"
  type        = number

  validation {
    condition = var.worker_pool_replicas > 0 && floor(var.worker_pool_replicas) == var.worker_pool_replicas

    error_message = "worker_pool_replicas must be a whole number greater than zero."
  }
}
