# Runtime

Creates the GKE clusters for each team location requested in the team tfvars. Each
workspace owns one zone, named `<zone>-runtime-<environment>` (for example
`us-east1-b-runtime-sandbox`), and reads that region's Assembly `runtime_networks`
output. The Sandbox fleet host cluster is selected by Assembly's `gke_fleet_host`.

Sandbox workspaces exist for `us-east1-b` and `us-east4-a` and apply only after manual
approval of their exact plans. Cluster services (cert-manager, Istio, OPA Gatekeeper) and
workload routes are not yet managed here.

```shell
TF_WORKSPACE=us-east1-b-runtime-sandbox tofu -chdir=runtime test
```
