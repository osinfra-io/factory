data "authentik_group" "all" {
  name = "all"
}

# Developers sign in with Google first, which creates their authentik user.
data "authentik_users" "approvers" {
  for_each = toset(var.approver_emails)

  email = each.value
}
