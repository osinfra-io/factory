---
sidebar_label: Environment lifecycle
description: The current bootstrap sequence and target state handoff for Factory environments.
---

# Environment lifecycle

The planned rollout uses the Local Floor to bootstrap Sandbox, Non-Production,
and Production through Assembly, in that order. Public DNS delegation is a gate
before Runtime. Runtime is then brought up in the same environment order. After
all three Runtime stages are ready, each environment's operational state can be
migrated to its own backend and its Floor can take over.

## Bootstrap sequence

```mermaid
flowchart TD
  classDef floor fill:#79C0AB,stroke:#79C0AB,color:#000
  classDef bootstrap fill:#8A3FFC,stroke:#8A3FFC,color:#fff
  classDef runtime fill:#466BB0,stroke:#466BB0,color:#fff
  classDef state fill:#23263B,stroke:#23263B,color:#fff
  classDef gate fill:#f9ab00,stroke:#f9ab00,color:#000
  classDef testing fill:#FD4B2D,stroke:#FD4B2D,color:#fff

  start["Start local development environment<br/>Factory Floor on Docker Desktop"]:::floor
  tests["Local end-to-end testing<br/>can run on the Local Floor"]:::testing
  start --> tests

  subgraph before_runtime["Wave 1 — Local Floor bootstraps through Assembly"]
    sandbox["Sandbox<br/>Seed, Foundation, Assembly main + regional"]:::bootstrap
    nonprod["Non-Production<br/>Environment setup, Foundation, Assembly main + regional"]:::bootstrap
    production["Production<br/>Environment setup, Foundation, Assembly main + regional"]:::bootstrap
    sandbox --> nonprod --> production
  end
  start --> sandbox

  production --> assembly_ready["All environments have DNS zones and nameserver outputs"]:::gate
  assembly_ready --> delegate["Update the Production-owned parent zone<br/>with verified Sandbox and Non-Production nameservers"]:::bootstrap
  delegate --> dns_ready["DNS delegation is publicly resolvable"]:::gate

  subgraph runtime_wave["Wave 2 — Runtime, in order"]
    sandbox_runtime["Sandbox Runtime"]:::runtime
    nonprod_runtime["Non-Production Runtime"]:::runtime
    production_runtime["Production Runtime"]:::runtime
    sandbox_runtime --> nonprod_runtime --> production_runtime
  end
  dns_ready --> sandbox_runtime
  start -. "Local Floor applies Runtime" .-> sandbox_runtime
  start -. "Local Floor applies Runtime" .-> nonprod_runtime
  start -. "Local Floor applies Runtime" .-> production_runtime

  production_runtime --> all_ready["All three Runtime stages are ready"]:::gate
  all_ready --> sandbox_state["Migrate Sandbox operational state<br/>to its environment backend"]:::state
  all_ready --> nonprod_state["Migrate Non-Production operational state<br/>to its environment backend"]:::state
  all_ready --> production_state["Migrate Production operational state<br/>to its environment backend"]:::state
  sandbox_state --> sandbox_floor["Sandbox Floor takes over reconciliation"]:::floor
  nonprod_state --> nonprod_floor["Non-Production Floor takes over reconciliation"]:::floor
  production_state --> production_floor["Production Floor takes over reconciliation"]:::floor
```

Assembly creates each environment's DNS zone and returns assigned nameservers.
The DNS gate represents publishing and verifying the delegations from the
Production-owned parent zone; creating the child zones alone does not satisfy
the gate.

## Ongoing ownership

```mermaid
flowchart LR
  classDef source fill:#23263B,stroke:#23263B,color:#fff
  classDef floor fill:#79C0AB,stroke:#79C0AB,color:#000
  classDef environment fill:#4285F4,stroke:#4285F4,color:#fff
  classDef testing fill:#FD4B2D,stroke:#FD4B2D,color:#fff
  classDef state fill:#23263B,stroke:#23263B,color:#fff

  repo["Factory Git repository"]:::source
  local["Local Factory Floor<br/>Docker Desktop"]:::floor
  tests["Local end-to-end testing"]:::testing
  repo --> local --> tests

  subgraph sandbox["Sandbox"]
    sandbox_floor["Sandbox Floor"]:::floor
    sandbox_work["Foundation, Assembly, Runtime"]:::environment
    sandbox_state["Sandbox credentials and state"]:::state
    sandbox_floor -. "reconciles" .-> sandbox_work
    sandbox_floor -. "uses" .-> sandbox_state
  end
  subgraph nonprod["Non-Production"]
    nonprod_floor["Non-Production Floor"]:::floor
    nonprod_work["Foundation, Assembly, Runtime"]:::environment
    nonprod_state["Non-Production credentials and state"]:::state
    nonprod_floor -. "reconciles" .-> nonprod_work
    nonprod_floor -. "uses" .-> nonprod_state
  end
  subgraph production["Production"]
    production_floor["Production Floor"]:::floor
    production_work["Foundation, Assembly, Runtime"]:::environment
    production_state["Production credentials and state"]:::state
    production_floor -. "reconciles" .-> production_work
    production_floor -. "uses" .-> production_state
  end

  repo -. "environment config" .-> sandbox_floor
  repo -. "environment config" .-> nonprod_floor
  repo -. "environment config" .-> production_floor
```

The seed's initial state is cluster-local and has a separate migration path:
the migration helper copies it to the environment backend, but switching the
seed workspace to that backend is a separate change. Migrating Foundation,
Assembly, or Runtime state does not transfer seed ownership. The cross-environment
configuration promotion policy is not defined in the current repository.
