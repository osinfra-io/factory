# Factory Team Folder Resource
# https://search.opentofu.org/provider/hashicorp/google/latest/docs/resources/google_folder

resource "google_folder" "teams" {
  for_each = var.teams

  deletion_protection = false
  display_name        = each.value.display_name
  parent              = local.environment_parent
}
