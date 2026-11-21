variable "locations" {
  default     = ["us-east1-b", "us-east4-a"]
  description = "Zones that run a Runtime cluster in this environment; every one joins the mesh"
  type        = list(string)
}
