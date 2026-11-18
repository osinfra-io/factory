---
name: bootstrap-sandbox
description: Bootstrap Factory's GCP Sandbox foundations from the local Docker Desktop Floor using reviewed, human-approved plans. Use when starting or resuming the Sandbox bootstrap.
---

# Bootstrap Factory Sandbox

Use the local Factory Floor to bootstrap the first GCP Sandbox environment. Keep the work staged and review each cloud plan through the Floor before approval. A plan approval starts an apply; never approve or apply a cloud plan automatically.

## Preconditions

- The Factory local integration stack is running and its Floor API is available. Follow `.github/skills/local-integration-testing/SKILL.md` to set it up.
- The currently checked-out Factory branch, including the bootstrap and Foundation source, is pushed so Flux can fetch it.
- `gcloud auth login` and `gcloud auth application-default login` are current for an account that can read the Sandbox folder. Never print or store access tokens. If authentication fails, stop and have the user refresh credentials.
- Use only the dedicated `docker-desktop` cluster. Never reset it during bootstrap.

The bootstrap uses cluster-local Terraform state and does not support surviving a Kubernetes reset. Keep Docker Desktop Kubernetes intact from initial preparation until all configured Sandbox stages are Ready. If it is reset during that window, stop; do not rerun preparation against existing cloud resources or create a new state. Treat cleanup or restarting the bootstrap as a separate explicit operation. If seed resources exist but their matching state is unavailable, stop and determine ownership before proceeding.

## Prepare the bootstrap

From the Factory repository root, run:

```bash
bash bootstrap/sandbox/prepare.sh
```

This validates access, creates the `bootstrap-sandbox` namespace and encrypted runner secrets, and registers the seed and Foundation Terraform objects with Flux. It does **not** approve or apply cloud changes. If the seed is already Ready, rerunning the script refreshes the short-lived Google credential and prepares the Foundation stage's KMS-backed state encryption.

Expose the bootstrap namespace through the local Floor API:

```bash
FLOOR_ADDITIONAL_NAMESPACES=bootstrap-sandbox \
  tests/integration/floor/setup.sh
```

This grants the API namespace-scoped access to bootstrap Terraform objects, not to their credential or state Secrets.

## Review and approve stages

Use the Floor tools `list_workspaces`, `pending_approvals`, and `get_workspace`. Outside the default namespace, pass the fully qualified object name, for example `bootstrap-sandbox/bootstrap-sandbox`. Review the exact pending plan, source revision, and workspace before presenting its changes to the user.

The stages are ordered by `dependsOn`: the seed `bootstrap-sandbox`, then `foundation-sandbox`, which creates the single Factory team folder. Approve only the exact pending plan after the user explicitly confirms that plan. Use its current plan ID; if the revision or plan changes, inspect and present the new plan instead. After approval, wait for the workspace to report Ready before proceeding.

Stop on plan errors, unexpected replacements or deletions, missing state, or an unexpected source revision. Do not repair state, import resources, or bypass a failed plan without explicit direction.

## Scope boundary

This bootstrap covers the Sandbox seed and Foundation stage for the Factory team. It does not create GKE, networking, team projects, or Non-Production and Production environments. Stop after the configured Sandbox stages are Ready and report the remaining handoff work; do not expand scope to those later stages.
