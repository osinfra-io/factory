#!/usr/bin/env bash

# Approve the exact plan shown by review.sh, then wait for the apply.
# Usage: approve.sh <environment> <stage> <plan-sha256-prefix>
# The plan ID and revision are re-read, and the readable plan hash must still match.
# Floor's non-approver identity cannot approve; this uses the local floor-verify identity.

set -euo pipefail
set +x
umask 077

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ENVIRONMENT="${1:?usage: approve.sh <environment> <stage> <plan-sha256-prefix>}"
STAGE="${2:?usage: approve.sh <environment> <stage> <plan-sha256-prefix>}"
HASH_PREFIX="${3:?usage: approve.sh <environment> <stage> <plan-sha256-prefix>}"
[ "${#HASH_PREFIX}" -ge 8 ] || { echo "Use at least 8 characters of the reviewed plan hash." >&2; exit 1; }
OBJECT="${STAGE}-${ENVIRONMENT}"
NAMESPACE="bootstrap-${ENVIRONMENT}"

review="$("${SCRIPT_DIR}/review.sh" "${ENVIRONMENT}" "${STAGE}")"
plan_id="$(sed -n 's/^Plan: //p' <<<"${review}")"
hash="$(sed -n 's/^Plan SHA-256: //p' <<<"${review}")"
case "${hash}" in
  "${HASH_PREFIX}"*) ;;
  *) echo "The pending plan differs from the reviewed plan (${hash:0:8}); review again." >&2; exit 1 ;;
esac

printf 'user = "floor-verify:%s"\n' "$(cat "${REPO_DIR}/tests/integration/floor/.work/auth/verify-token")" |
  curl --config - --noproxy '*' --cacert "${REPO_DIR}/tests/integration/istio/.work/gateway-localhost.crt" \
    --fail --silent --show-error --max-time 30 \
    --header 'Accept: application/json, text/event-stream' \
    --header 'Content-Type: application/json' \
    --data "$(jq -nc --arg name "${NAMESPACE}/${OBJECT}" --arg plan "${plan_id}" \
      '{jsonrpc:"2.0",id:1,method:"tools/call",params:{name:"approve",arguments:{name:$name,planId:$plan}}}')" \
    https://floor.localhost/mcp |
  sed -n 's/^data: //; /^{/p' |
  jq -e 'if .error or .result.isError then error(.error.message // .result.content[0].text) else .result.structuredContent.message end'

for _ in $(seq 1 90); do
  state="$(kubectl --context=docker-desktop --namespace="${NAMESPACE}" get terraform "${OBJECT}" -o json |
    jq -r '.status.conditions[]? | select(.type == "Ready") | "\(.status)\t\(.message[0:200])"' | sed 's/\x1b\[[0-9;]*m//g')"
  case "${state}" in
    True*) echo "${OBJECT} applied: ${state#*$'\t'}"; exit 0 ;;
    False*dependency*) ;;
    False*) echo "${OBJECT} failed: ${state#*$'\t'}" >&2; exit 1 ;;
  esac
  sleep 10
done
echo "Timed out waiting for ${OBJECT}; check its status." >&2
exit 1
