---
sidebar_label: Run Factory
description: Implementation and operations guidance for the Factory platform team.
---

# Run Factory

This section is for platform engineers who own the Factory codebase and
operate the platform end to end. It covers the implementation, environment
lifecycle, and Floor's reviewed OpenTofu workflow.

- [Architecture overview](./architecture/index.md)
- [Environment lifecycle](./architecture/environment-lifecycle.md)
- [Floor](./architecture/floor.md)
- [Local development and testing](./local-development.md)

The lifecycle describes a planned rollout and state handoff. See the
[architecture overview](./architecture/index.md#current-implementation-boundary)
for what is currently represented in the repository.

## Factory CLI

The `factory` CLI connects to Floor to show workspaces, review pending plans,
and approve or reject changes. Reviewing plans requires access to the
configured Kubernetes context. Approving a plan starts an apply.

After setting up the local Floor and CLI environment, run from the repository
root:

```bash
cd cli
go run ./cmd/factory --env local
```

See the [CLI guide](https://github.com/osinfra-io/factory/blob/main/cli/README.md)
for configuration, sign-in, and controls.
