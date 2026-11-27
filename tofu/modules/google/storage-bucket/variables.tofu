# Input Variables
# https://opentofu.org/docs/language/values/variables

variable "default_kms_key_name" {
  default     = null
  description = "The name of the Cloud KMS key that will be used to encrypt objects inserted into this bucket"
  type        = string
}

variable "force_destroy" {
  default     = false
  description = "When deleting a bucket, this boolean option will delete all contained objects"
  type        = bool
}

variable "labels" {
  default     = {}
  description = "A map of key/value pairs to assign to the resources being created"
  type        = map(string)
}

variable "location" {
  description = "The location the storage bucket will be created in"
  type        = string
}

variable "name" {
  description = "The name of the storage bucket"
  type        = string
}

variable "project" {
  description = "The ID of the project in which the resource belongs"
  type        = string
}

variable "public_access_prevention" {
  default     = "enforced"
  description = "The public access prevention configuration for the bucket"
  type        = string

  validation {
    condition     = contains(["enforced", "inherited"], var.public_access_prevention)
    error_message = "The public_access_prevention must be one of: enforced, inherited"
  }
}

variable "storage_class" {
  default     = "STANDARD"
  description = "The Storage Class of the new bucket. Supported values include: STANDARD, MULTI_REGIONAL, REGIONAL, NEARLINE, COLDLINE, ARCHIVE"
  type        = string

  validation {
    condition     = contains(["STANDARD", "MULTI_REGIONAL", "REGIONAL", "NEARLINE", "COLDLINE", "ARCHIVE"], var.storage_class)
    error_message = "The storage_class must be one of: STANDARD, MULTI_REGIONAL, REGIONAL, NEARLINE, COLDLINE, ARCHIVE"
  }
}

variable "versioning" {
  default     = true
  description = "The bucket's Versioning configuration"
  type        = bool
}
