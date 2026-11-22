# State graph (future work)

## Problem

Factory stages (bootstrap, foundation, assembly, and later runtime) run in a fixed order. Today that order is declared with Flux/tofu-controller `dependsOn`, which means only "wait until X is Ready". It does not say whether a run actually needed anything from X.

Understanding dependencies is central to Factory. For example, an assembly run should be able to show that it needed nothing from bootstrap or foundation in that run.

## Current state

- `dependsOn` is declared ordering only.
- Floor lists it per workspace (`dependsOn`), and the CLI shows what an approved plan is waiting on.
- Nothing records which upstream outputs or remote state a plan actually read, or whether they changed.

## Example: changing one Runtime stage

Changing only `authentik-config` shows the gap. Every push gives all Floor objects a new source revision, so each one re-plans, and a stage behind an unready dependency waits (`DependencyNotReady`). Unchanged stages produce no-op plans that need no approval, and only `authentik-config` is reviewed and approved. Today the operator must know this; the graph should show which upstream stages a run read (`istio-global`, `authentik-global`) and that none of their values changed, so the rest of the chain is visibly irrelevant.

## Direction

- **Floor API owns the graph data.** It already flattens Terraform objects. It should add per-run `reads` (upstream outputs or state a plan consumed) and `changed` (whether those inputs differ from the previous run).
- **Capture at plan time.** Compare upstream values read by a plan with the previous run. The plan JSON lists data-source reads but not which upstream state they came from, so the runner or Floor must record this.
- **Store per-run metadata** on the Terraform object (annotation or status) or a small run record. Design this with the Runtime layer so it is not Sandbox-only.
- **The CLI only renders** the graph; it does not compute it.

## When

Not yet. Do this once Floor has a place to store per-run metadata.
