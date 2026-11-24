---
sidebar_label: Foundation
description: Foundation's current OpenTofu scope and outputs.
---

# Foundation

Foundation establishes the folder boundary and publishes metadata used by
downstream layers. Its current OpenTofu root is `tofu/foundation/`.

The root creates a Google Cloud folder for each configured team beneath the
existing environment root folder. It outputs the environment root folder ID and
the team folder and environment metadata.

The checked-in team input defines one team, `factory`. Foundation is deliberately
minimal: this root does not provision identity integrations, organization
policies, or third-party service configuration.

Foundation reads environment and team inputs and uses the configured Google
Cloud provider and state backend. Assembly consumes its outputs; it does not
own or rewrite Foundation state.

## Bootstrap dependency

Before Foundation can use its encrypted Google Cloud Storage backend, the
environment seed must create the bootstrap project, bucket, KMS key, and runner
identities. The seed is a separate root under `bootstrap/seed/`. Its initial
state is stored in the local Kubernetes cluster; Foundation state is stored in
the seed project's backend.
