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

`bootstrap/seed/runtime.sh` tears down and rebuilds the Runtime through the Floor.

```shell
bootstrap/seed/runtime.sh sandbox status    # objects, pending plans, destroy/suspend flags
bootstrap/seed/runtime.sh sandbox down      # fast: delete clusters, stop Cloud SQL, drop zonal state
bootstrap/seed/runtime.sh sandbox destroy   # graceful: reviewed destroy plans, dependents first
bootstrap/seed/runtime.sh sandbox up        # start Cloud SQL, recreate in dependency order
bootstrap/seed/runtime.sh sandbox config    # openbao-config, after openbao is initialised
```

`down` suspends the zonal objects and both configuration stages, deletes the clusters (which
removes everything inside them), stops Cloud SQL and deletes the zonal state, so `up` creates
from scratch; each plan on `up` is shown and approved only when you type its hash prefix back.
`destroy` is the slow path that reviews every destroy plan. Assembly and the global stages are
untouched, and authentik's data survives in Cloud SQL; OpenBao data does not, so initialise and
unseal it after `up`, refresh the `floor-openbao-auth` secret, then run
`config`. Scale-to-zero is tracked in
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
