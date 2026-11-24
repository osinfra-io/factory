---
sidebar_label: Floor
description: Floor's local orchestration and reviewed OpenTofu workflow.
---

# Floor

Floor is Factory's execution and orchestration environment, not another
infrastructure layer. The current local Factory Floor runs on Docker Desktop.
It hosts Flux and tofu-controller, which reconcile repository configuration
and create OpenTofu plans for review.

The Floor API exposes workspace status and approval operations in configured
namespaces. It reports pending plan IDs, not plan contents. The `factory` CLI
can read and display a plan using the operator's configured Kubernetes
context; the bootstrap review helper reads the controller's plan Secret as
well. A plan must be reviewed and explicitly approved before an apply;
registering or reconciling a workspace does not itself approve cloud changes.

See the [factory CLI guide](https://github.com/osinfra-io/factory/blob/main/cli/README.md)
and [bootstrap skill](https://github.com/osinfra-io/factory/blob/main/.github/skills/bootstrap-sandbox/SKILL.md)
for their setup and review workflows.

The bootstrap flow initially uses the Local Floor. The target is to hand
ongoing reconciliation to an environment's own Floor after that environment is
ready and its state ownership has been deliberately transferred. The Local
Floor remains useful for local end-to-end testing.
