#!/usr/bin/env bash

# Report the state of the Runtime Floor objects for an environment, so pending
# plans can be found and reviewed with review.sh before approve.sh.
# Usage: runtime.sh <environment> status

set -euo pipefail

ENVIRONMENT="${1:?usage: runtime.sh <environment> status}"
[ "${2:-status}" = "status" ] || { echo "Only 'status' is supported; changes go through review.sh and approve.sh." >&2; exit 2; }

kubectl --context=docker-desktop --namespace="bootstrap-${ENVIRONMENT}" get terraform -o json |
  jq -r --arg suffix "-${ENVIRONMENT}" '
    .items[] | select(.metadata.name | endswith($suffix)) |
    [.metadata.name,
     ((.status.conditions // [] | map(select(.type == "Ready")) | .[0].status) // "Unknown"),
     (if (.status.plan.pending // "") != "" then "PENDING-PLAN" else "-" end)] | @tsv' |
  sort | column -t
