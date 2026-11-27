locals {
  kubernetes_manifest_block_ingress_constraint_template_manifest = {
    apiVersion = "templates.gatekeeper.sh/v1"
    kind       = "ConstraintTemplate"

    metadata = {
      name = "k8sblockingress"
    }

    spec = {
      crd = {
        spec = {
          names = {
            kind = "K8sBlockIngress"
          }
        }
      }

      targets = [
        {
          target = "admission.k8s.gatekeeper.sh"

          code = [
            {
              engine = "Rego"

              source = {
                version = "v1"
                rego    = file("${path.module}/k8sblockingress/k8sblockingress.rego")
              }
            }
          ]
        }
      ]
    }
  }

  kubernetes_manifest_protect_gateway_auth_constraint_template_manifest = {
    apiVersion = "templates.gatekeeper.sh/v1"
    kind       = "ConstraintTemplate"

    metadata = {
      name = "k8sprotectgatewayauth"
    }

    spec = {
      crd = {
        spec = {
          names = {
            kind = "K8sProtectGatewayAuth"
          }

          validation = {
            openAPIV3Schema = {
              properties = {
                allowedGroups = {
                  items = {
                    type = "string"
                  }

                  type = "array"
                }

                allowedUsers = {
                  items = {
                    type = "string"
                  }

                  type = "array"
                }

                protectedKinds = {
                  items = {
                    properties = {
                      apiGroup = {
                        pattern = "^$|^\\S(?:.*\\S)?$"
                        type    = "string"
                      }

                      kind = {
                        pattern = "^\\S(?:.*\\S)?$"
                        type    = "string"
                      }
                    }

                    required = ["apiGroup", "kind"]
                    type     = "object"
                  }

                  type = "array"
                }

                protectedNamespaces = {
                  items = {
                    pattern = "^\\S(?:.*\\S)?$"
                    type    = "string"
                  }

                  type = "array"
                }
              }

              required = ["allowedGroups", "allowedUsers", "protectedKinds", "protectedNamespaces"]
              type     = "object"
            }
          }
        }
      }

      targets = [
        {
          target = "admission.k8s.gatekeeper.sh"

          code = [
            {
              engine = "Rego"

              source = {
                version = "v1"
                rego    = file("${path.module}/k8sprotectgatewayauth/k8sprotectgatewayauth.rego")
              }
            }
          ]
        }
      ]
    }
  }
}
