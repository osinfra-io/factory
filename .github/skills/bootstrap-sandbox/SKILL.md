---
name: bootstrap-sandbox
description: Bootstrap Factory's GCP Sandbox foundations from the local Docker Desktop Floor using reviewed, human-approved plans. Use when starting or resuming the Sandbox bootstrap.
---

# Bootstrap Factory Sandbox

Use the local Factory Floor to bootstrap the first GCP Sandbox environment. Keep the work staged and review each cloud plan before approval. A plan approval starts an apply; never approve or apply a cloud plan automatically.

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

This grants the API namespace-scoped access to bootstrap Terraform objects, not to Secrets. It does not register tools in Copilot or require a CLI extension.

## Review and approve stages

Process stages in order: review and approve `bootstrap-sandbox` first, then `foundation-sandbox`, which creates the single Factory team folder. Do not query or inspect the Foundation workspace until the seed reports Ready. From the Factory root, call the Floor MCP endpoint directly if its tools are not already connected. Use the non-approver identity created by Floor setup; do not print or register its app password in Copilot settings.

```bash
set -euo pipefail
object=bootstrap-sandbox
token_file=tests/integration/floor/.work/auth/visitor-token
test -s "$token_file" || { echo "Missing Floor visitor app password; check Floor setup." >&2; exit 1; }
printf 'user = "floor-visitor:%s"\n' "$(cat "$token_file")" |
  curl --config - --noproxy '*' --cacert tests/integration/istio/.work/gateway-localhost.crt \
    --fail --silent --show-error --max-time 15 \
    --header 'Accept: application/json, text/event-stream' \
    --header 'Content-Type: application/json' \
    --data "$(jq -nc --arg name "bootstrap-sandbox/$object" \
      '{jsonrpc:"2.0",id:1,method:"tools/call",params:{name:"get_workspace",arguments:{name:$name}}}')" \
    https://floor.localhost/mcp |
  sed -n 's/^data: //; /^{/p' |
  jq -e 'if .error or .result.isError
    then error(.error.message // .result.content[0].text)
    else .result.structuredContent.workspace end'
```

`get_workspace` reports the pending plan ID, not its contents. If there is no pending plan, check the Terraform object's Ready condition: proceed only if the seed is Ready; otherwise stop. For a pending plan, use the local Kubernetes context to read **only** the controller's readable JSON plan Secret. Verify the plan ID matches Floor and the planned revision matches the expected pushed commit. This command checks that the plan belongs to the current Terraform object and is still current after reading it:

```bash
set -euo pipefail
object=bootstrap-sandbox # Use the same object as in the Floor query.
kube=(kubectl --context=docker-desktop --namespace=bootstrap-sandbox)
pending() {
  "${kube[@]}" get terraform "$object" -o json | jq -er '
    if (.status.plan.pending // "") != "" and
       (.status.lastPlannedRevision // "") != "" and
       .status.lastPlannedRevision == .status.lastAttemptedRevision and
       .status.lastPlannedGeneration == .metadata.generation
    then [.metadata.uid, .spec.workspace, .status.plan.pending, .status.lastPlannedRevision] | @tsv
    else error("No current pending plan") end'
}
snapshot=$(pending)
IFS=$'\t' read -r uid workspace plan_id revision <<< "$snapshot"
plan=$("${kube[@]}" get secret "tfplan-$workspace-$object.json" -o json |
  jq -er --arg uid "$uid" --arg id "$plan_id" '
    if .metadata.annotations.savedPlan == $id and .metadata.annotations.encoding == "gzip" and
       any(.metadata.ownerReferences[]?; .kind == "Terraform" and .uid == $uid)
    then .data.tfplan else error("Readable plan does not match the pending plan") end' |
  base64 --decode | gzip --decompress --stdout)
test "$(pending)" = "$snapshot" || { echo "Pending plan changed; review again." >&2; exit 1; }
printf 'Workspace: %s\nRevision: %s\nPlan: %s\n' "$workspace" "$revision" "$plan_id"
printf 'Readable plan SHA-256: '
printf '%s' "$plan" | sha256sum
jq -e '{
  resources: [.resource_changes[]? | select(.change.actions != ["no-op"]) | {
    address,
    actions: .change.actions,
    details: (.change.after // {} | with_entries(select(
      .key == "account_id" or .key == "display_name" or .key == "folder_id" or
      .key == "location" or .key == "name" or .key == "project_id" or
      .key == "service"
    )))
  }],
  drift: [.resource_drift[]? | {address, actions: .change.actions}],
  outputs: [.output_changes // {} | to_entries[] | select(.value.actions != ["no-op"]) | {name: .key, actions: .value.actions}]
}' <<< "$plan"
unset plan
```

Review the listed changes and selected non-sensitive identifiers from this read. If more detail is needed, add a focused projection from the in-memory `$plan` before unsetting it; do not reread the plan Secret for initial review. Never dump the raw JSON plan into the conversation or read the binary plan, credential, or state Secrets. If the readable plan is missing or cannot be matched, stop.

Present the workspace, revision, plan ID, and planned changes. After the user explicitly confirms that exact plan, repeat the read and check that the revision, plan ID, and readable plan hash are unchanged. Only then call Floor's `approve` MCP tool with the fully qualified `name` and exact `planId` using an authorized approver identity. If the tool is not connected in the CLI, use the same `tools/call` request pattern against the MCP endpoint with `floor-verify` and `tests/integration/floor/.work/auth/verify-token` from local Floor setup; never patch `spec.approvePlan` directly. After approval, wait for the workspace to report Ready, then repeat the workspace and plan-review procedure with `object=foundation-sandbox`.

Stop on plan errors, unexpected replacements or deletions, missing state, or an unexpected source revision. Do not repair state, import resources, or bypass a failed plan without explicit direction.

## Scope boundary

This bootstrap covers the Sandbox seed and Foundation stage for the Factory team. It does not create GKE, networking, team projects, or Non-Production and Production environments. Stop after the configured Sandbox stages are Ready and report the remaining handoff work; do not expand scope to those later stages.
