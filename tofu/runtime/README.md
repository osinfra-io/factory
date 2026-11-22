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

`bootstrap/seed/runtime.sh` drives teardown and rebuild through the Floor. It orders the zonal
Runtime objects by their `dependsOn` graph, sets the controller's `spec.destroy` flag tier by
tier, and shows each plan. A plan is approved only when you type its hash prefix back, so every
destroy is still reviewed.

```shell
bootstrap/seed/runtime.sh sandbox status   # objects, pending plans, destroy/suspend flags
bootstrap/seed/runtime.sh sandbox down     # dependents first, clusters last
bootstrap/seed/runtime.sh sandbox up       # dependencies first, then authentik-config
bootstrap/seed/runtime.sh sandbox config   # openbao-config, after openbao is initialised
```

`down` suspends `authentik-config` and `openbao-config` while the clusters are gone. Assembly,
the global stages and Cloud SQL are untouched, so authentik's data survives; OpenBao data does
not, so initialise and unseal it after `up`, refresh the `floor-openbao-auth` secret, then run
`config`. Stopping Cloud SQL while idle and scale-to-zero are tracked in
[#3](https://github.com/osinfra-io/factory/issues/3). The `runtime_enabled` variable remains
available to disable a stage through its tfvars.

## Tests

Run the mocked tests from the repository root:

```shell
TF_WORKSPACE=us-east1-b-runtime-sandbox tofu -chdir=tofu/runtime/cluster test
```

## Future work

kagent and agent-substrate have Factory modules and local integration fixtures only. They are
not deployed to Sandbox because pneuma has no equivalent.
