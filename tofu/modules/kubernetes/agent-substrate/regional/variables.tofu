# Input Variables
# https://opentofu.org/docs/language/values/variables

variable "chart_repository" {
  default     = "oci://ghcr.io/kagent-dev/substrate/helm"
  description = "OCI repository containing the Agent Substrate Helm charts"
  type        = string
}

variable "crds_postrender" {
  default     = null
  description = "Optional Helm post-renderer for the CRD chart; local fixtures use it to retain cluster-wide CRDs on uninstall"
  type = object({
    args        = optional(list(string), [])
    binary_path = string
  })
}

variable "ingress_allowed_spiffe_ids" {
  default     = []
  description = "mTLS client SPIFFE IDs allowed to reach actors through the router, for example spiffe://cluster.local/ns/kagent/sa/kagent-controller; an empty list denies all ingress"
  type        = list(string)
}

variable "namespace" {
  description = "Kubernetes namespace for Agent Substrate"
  type        = string
}

variable "object_store_credentials_secret_name" {
  default     = "rustfs-credentials"
  description = "Existing Secret in the namespace with AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY keys for the bundled RustFS snapshot store; atelet reads it"
  type        = string
}

variable "postgres_owner_secret_name" {
  default     = "substrate-postgres-owner"
  description = "Existing Secret whose ownerConnectionString key holds the PostgreSQL owner connection string; the owner creates the schema and runs migrations"
  type        = string
}

variable "postgres_read_write_secret_name" {
  default     = "substrate-postgres-readwrite"
  description = "Existing Secret whose readWriteConnectionString key holds the PostgreSQL read/write connection string used for runtime queries"
  type        = string
}

variable "rustfs_access_key" {
  description = "Access key for the bundled RustFS snapshot store; must match AWS_ACCESS_KEY_ID in the object store credentials Secret"
  sensitive   = true
  type        = string
}

variable "rustfs_secret_key" {
  description = "Secret key for the bundled RustFS snapshot store; must match AWS_SECRET_ACCESS_KEY in the object store credentials Secret"
  sensitive   = true
  type        = string
}

variable "substrate_version" {
  default     = "1.0.1"
  description = "Agent Substrate Helm chart version"
  type        = string
}
