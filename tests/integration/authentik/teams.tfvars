teams = {
  factory = {
    authentik_groups = {
      agentgateway-admins = {
        description = "Access to the local agentgateway applications"
        label       = "agentgateway Admins"
      }
      authentik-admins = {
        description = "Local Authentik administrator access"
        label       = "Authentik Admins"
      }
      floor-approvers = {
        description = "Approve local floor plans"
        label       = "floor Approvers"
      }
      kagent-admins = {
        description = "Access to the local kagent application"
        label       = "kagent Admins"
      }
      openbao-secret-admins = {
        description = "Manage local OpenBao secrets and versions"
        label       = "OpenBao Secret Admins"
      }
      openbao-secret-readers = {
        description = "Read local OpenBao secrets"
        label       = "OpenBao Secret Readers"
      }
      openbao-secret-writers = {
        description = "Create and update local OpenBao secrets"
        label       = "OpenBao Secret Writers"
      }
    }
  }
}
