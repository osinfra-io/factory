---
sidebar_label: Overview
description: The Factory architecture and what is currently represented in the repository.
---

# Factory architecture

Factory is an infrastructure-as-code reference architecture. Its three layers
have distinct responsibilities:

| Layer | Responsibility in this repository |
| --- | --- |
| Foundation | Establishes environment and team folders and publishes metadata for downstream configuration. |
| Assembly | Provisions cloud projects and shared infrastructure, including networking, DNS, registry, and regional resources. |
| Runtime | Creates GKE clusters for configured team locations using Assembly network outputs. |

**Floor** is the execution and orchestration environment across these layers. It
is not a fourth infrastructure layer. The current local Floor runs on Docker
Desktop and uses Flux and tofu-controller to plan and reconcile OpenTofu
workspaces.

## Code in this repository

- `bootstrap/seed/` creates an environment's bootstrap project, state bucket,
  KMS key, and runner identities. Its initial state is cluster-local.
- `tofu/foundation/` creates configured team folders under an existing
  environment folder and publishes Foundation outputs.
- `tofu/assembly/` contains the main and regional infrastructure roots.
- `tofu/runtime/` creates GKE clusters from regional Assembly outputs.
- `tofu/modules/` contains reusable Google Cloud and Kubernetes modules.
- `floor/` contains the local Floor API and Flux configuration.
- `cli/` contains a terminal interface for viewing workspaces and reviewing
  plans through Floor and the configured Kubernetes context.
- `tests/integration/` contains the opt-in local Docker Desktop integration
  stack.

## Current implementation boundary

Sandbox has bootstrap, Foundation, and Assembly configuration. Runtime
configuration exists for the Sandbox `us-east1-b` and `us-east4-a` workspaces.
Non-Production and Production also have bootstrap, Foundation, and Assembly
configuration, but no Runtime Floor workspaces are checked in for them. The
Runtime root does not yet install cluster services or workload routes.

These are repository configuration facts, not claims about which cloud plans
have been approved or applied. The docs describe the code and configured
workflow; they do not imply that an environment is live.

## Architecture pages

- [Environment lifecycle](./environment-lifecycle.md)
- [Foundation](./foundation.md)
- [Assembly](./assembly.md)
- [Runtime](./runtime.md)
- [Floor](./floor.md)
- [Local development and testing](../local-development.md)
