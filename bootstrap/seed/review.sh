#!/usr/bin/env bash

# Print the pending plan for a bootstrap Terraform object so it can be reviewed
# before approve.sh. Usage: review.sh <environment> <stage>
# <stage> is the object name without the environment suffix, for example
# bootstrap, foundation, assembly or assembly-us-east1. Pass --wait to poll for a plan.

set -euo pipefail
set +x
umask 077

ENVIRONMENT="${1:?usage: review.sh <environment> <stage> [--wait]}"
OBJECT="${2:?usage: review.sh <environment> <stage> [--wait]}-${ENVIRONMENT}"
NAMESPACE="bootstrap-${ENVIRONMENT}"
kube=(kubectl --context=docker-desktop --namespace="${NAMESPACE}")

pending() {
  "${kube[@]}" get terraform "${OBJECT}" -o json | jq -er '
    if (.status.plan.pending // "") != "" and
       .status.lastPlannedRevision == .status.lastAttemptedRevision and
       .status.lastPlannedGeneration == .metadata.generation
    then [.metadata.uid, .spec.workspace, .status.plan.pending, .status.lastPlannedRevision] | @tsv
    else error("No current pending plan") end' 2>/dev/null
}

snapshot=""
for _ in $(seq 1 60); do
  snapshot="$(pending || true)"
  [ -n "${snapshot}" ] && break
  [ "${3:-}" = "--wait" ] || break
  sleep 10
done
if [ -z "${snapshot}" ]; then
  "${kube[@]}" get terraform "${OBJECT}" -o json |
    jq -r '"No pending plan. Ready: \(.status.conditions[]? | select(.type == "Ready") | "\(.status) \(.message[0:300])")"' |
    sed 's/\x1b\[[0-9;]*m//g'
  exit 1
fi

IFS=$'\t' read -r uid workspace plan_id revision <<<"${snapshot}"
plan="$("${kube[@]}" get secret "tfplan-${workspace}-${OBJECT}.json" -o json |
  jq -er --arg uid "${uid}" --arg id "${plan_id}" '
    if .metadata.annotations.savedPlan == $id and
       any(.metadata.ownerReferences[]?; .kind == "Terraform" and .uid == $uid)
    then .data.tfplan else error("Readable plan does not match the pending plan") end' |
  base64 --decode | gzip --decompress --stdout)"
[ "$(pending)" = "${snapshot}" ] || { echo "Pending plan changed; review again." >&2; exit 1; }

printf 'Object: %s/%s\nWorkspace: %s\nRevision: %s\nPlan: %s\nPlan SHA-256: %s\n' \
  "${NAMESPACE}" "${OBJECT}" "${workspace}" "${revision}" "${plan_id}" \
  "$(printf '%s' "${plan}" | sha256sum | cut -d' ' -f1)"
jq -c '
  (.resource_changes[]? | select(.change.actions != ["no-op"]) | {
    address, actions: .change.actions,
    details: (.change.after // {} | with_entries(select(.key | IN(
      "account_id", "display_name", "folder_id", "location", "name", "project_id",
      "service", "ip_cidr_range", "dns_name"))))
  }),
  (.resource_drift[]? | {drift: .address, actions: .change.actions}),
  (.output_changes // {} | to_entries[] | select(.value.actions != ["no-op"]) |
    {output: .key, actions: .value.actions})' <<<"${plan}"
echo "Summary: $(jq -r '[.resource_changes[]? | select(.change.actions != ["no-op"]) | .change.actions | join("+")] | group_by(.) | map("\(length) \(.[0])") | join(", ")' <<<"${plan}")"
jq -e '[.resource_changes[]? | select(.change.actions | index("delete"))] | length == 0' <<<"${plan}" >/dev/null ||
  echo "WARNING: this plan deletes or replaces resources." >&2
