# Local Values
# https://opentofu.org/docs/language/values/locals

# The local test group keeps this identity out of application groups owned by the
# authentik configuration. The binding group only authenticates the caller.

locals {
  # Members are the verification user and developers who already signed in with Google.
  approver_user_ids = concat(
    [tonumber(authentik_user.floor_verify.id)],
    flatten([for users in data.authentik_users.approvers : [for user in users.users : user.pk]]),
  )

  # An address keeps the local accounts distinct from the other local identities.
  verify_email = "${var.username}@localhost"

  verify_group_ids = [data.authentik_group.all.id]
  visitor_email    = "${var.visitor_username}@localhost"
}
