# Runtime

Runtime is disposable. It is split into two stages per zone, each with its own Floor object
and state:

| Stage | Path | Workspace | Purpose |
| --- | --- | --- | --- |
| `cluster` | `tofu/runtime/cluster` | `<zone>-runtime-<environment>` | GKE cluster for the zone |
| `workloads` | `tofu/runtime/workloads` | `<zone>-workloads-<environment>` | Kubernetes ecosystem running on the cluster |

Both stages read their zone's Assembly `runtime_networks` output. Sandbox runs `us-east1-b`
and `us-east4-a`. Every plan is reviewed and approved through Floor.

## Tear down and recreate

`runtime_enabled` (default `true`) controls whether the stages declare anything. Set it to
`false` to destroy Runtime so it stops costing money, and back to `true` to recreate it.
Assembly (projects, network, DNS) is never touched.

```shell
bootstrap/seed/runtime.sh down sandbox
bootstrap/seed/runtime.sh up sandbox
bootstrap/seed/runtime.sh status sandbox
```

Destroying removes in-cluster data, so rebuild OpenBao and authentik state from code after
`up`. Scale-to-zero while idle is tracked in
[#3](https://github.com/osinfra-io/factory/issues/3).

## Tests

Run the mocked tests from the repository root:

```shell
TF_WORKSPACE=us-east1-b-runtime-sandbox tofu -chdir=tofu/runtime/cluster test
```
