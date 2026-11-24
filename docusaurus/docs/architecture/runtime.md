---
sidebar_label: Runtime
description: Runtime's current GKE workspace scope and dependencies.
---

# Runtime

Runtime creates GKE clusters for the team locations requested in team
configuration. Its OpenTofu root is `tofu/runtime/`. Each workspace owns one
zone, named `<zone>-runtime-<environment>`, and reads that region's Assembly
`runtime_networks` output.

The Sandbox Floor configuration declares Runtime workspaces for
`us-east1-b` and `us-east4-a`. These workspaces depend on their corresponding
regional Assembly workspaces and require review and approval of their exact
plans before applying.

The Runtime root currently provisions clusters. It does not yet manage
cluster services such as cert-manager, Istio, or OPA Gatekeeper, or workload
routes. Reusable Kubernetes modules and the local integration stack are separate
from this cloud Runtime deployment.
