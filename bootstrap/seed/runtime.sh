#!/usr/bin/env bash

# Tear down or rebuild the Runtime for an environment through the Floor, one reviewed plan at a time.
# Usage: runtime.sh <environment> <status|down|up|config>
#
#   status  list Runtime objects, pending plans, and destroy/suspend flags
#   down    destroy every zonal Runtime object, dependents first, ending with the clusters
#   up      recreate them in dependency order, then reconcile authentik-config
#   config  reconcile openbao-config; run after openbao is initialised and unsealed
#
# Every plan is shown and approved only when its hash prefix is typed back; nothing is approved
# automatically. The in-cluster stages are destroyed through the controller's `spec.destroy`
# flag, and the two configuration stages are suspended while the clusters are gone, so
# Assembly (projects, network, DNS, Cloud SQL) and the global stages keep their state.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENVIRONMENT="${1:?usage: runtime.sh <environment> <status|down|up|config>}"
COMMAND="${2:?usage: runtime.sh <environment> <status|down|up|config>}"
NAMESPACE="bootstrap-${ENVIRONMENT}"
OPENBAO_CONFIG="openbao-config-${ENVIRONMENT}"
CONFIG_OBJECTS=("authentik-config-${ENVIRONMENT}" "${OPENBAO_CONFIG}")
kube=(kubectl --context=docker-desktop --namespace="${NAMESPACE}")

is_config() {
  local object
  for object in "${CONFIG_OBJECTS[@]}"; do
    [ "${object}" = "$1" ] && return 0
  done
  return 1
}

stage_of() {
  echo "${1%-"${ENVIRONMENT}"}"
}

patch() {
  "${kube[@]}" patch terraform "$1" --type=merge --field-manager=runtime-sh --patch "$2" >/dev/null
}

tiers() {
  "${kube[@]}" get terraform -o json | python3 "${SCRIPT_DIR}/runtime-order.py" "${ENVIRONMENT}"
}

# Prints plan, ready, failed or timeout once the object has reconciled its current spec.
wait_for_plan() {
  local object="$1" state
  for _ in $(seq 1 180); do
    state="$("${kube[@]}" get terraform "${object}" -o json | jq -r '
      (.status.conditions // [] | map(select(.type == "Ready")) | .[0]) as $ready |
      if (.status.plan.pending // "") != "" and .status.lastPlannedGeneration == .metadata.generation then "plan"
      elif $ready.status == "True" and .status.observedGeneration == .metadata.generation and ((.status.plan.pending // "") == "") then "ready"
      elif $ready.status == "False" and (($ready.message // "") | test("dependency|Dependency") | not) and .status.observedGeneration == .metadata.generation then "failed: \($ready.message[0:300])"
      else "waiting" end' | sed 's/\x1b\[[0-9;]*m//g')"
    [ "${state}" = "waiting" ] || { echo "${state}"; return 0; }
    sleep 10
  done
  echo "timeout"
}

process() {
  local object="$1" state reply
  state="$(wait_for_plan "${object}")"
  case "${state}" in
    ready) echo "${object}: nothing to change."; return 0 ;;
    plan) ;;
    *) echo "${object}: ${state}. Fix it, then rerun this command." >&2; exit 1 ;;
  esac
  "${SCRIPT_DIR}/review.sh" "${ENVIRONMENT}" "$(stage_of "${object}")"
  [ -t 0 ] || { echo "Run interactively to approve plans." >&2; exit 1; }
  read -r -p "Type the plan SHA-256 prefix (8+ characters) to approve ${object}, or press Enter to stop: " reply
  [ -n "${reply}" ] || { echo "Stopped before approving ${object}." >&2; exit 1; }
  "${SCRIPT_DIR}/approve.sh" "${ENVIRONMENT}" "$(stage_of "${object}")" "${reply}"
}

# Applies the switch to every object in the tier first so the plans are produced concurrently,
# then walks them one at a time for review.
run_tier() {
  local direction="$1" object
  shift
  for object in "$@"; do
    [ "${object}" = "${OPENBAO_CONFIG}" ] && [ "${direction}" = up ] && continue
    if is_config "${object}"; then
      if [ "${direction}" = down ]; then
        patch "${object}" '{"spec":{"suspend":true}}'
      else
        patch "${object}" '{"spec":{"suspend":false}}'
      fi
    elif [ "${direction}" = down ]; then
      patch "${object}" '{"spec":{"destroy":true}}'
    else
      patch "${object}" '{"spec":{"destroy":false}}'
    fi
  done
  for object in "$@"; do
    [ "${object}" = "${OPENBAO_CONFIG}" ] && [ "${direction}" = up ] && continue
    if [ "${direction}" = down ] && is_config "${object}"; then
      echo "${object}: suspended while the clusters are gone."
    else
      process "${object}"
    fi
  done
}

case "${COMMAND}" in
  status)
    "${kube[@]}" get terraform -o json |
      jq -r --arg suffix "-${ENVIRONMENT}" '
        .items[] | select(.metadata.name | endswith($suffix)) |
        [.metadata.name,
         ((.status.conditions // [] | map(select(.type == "Ready")) | .[0].status) // "Unknown"),
         (if (.status.plan.pending // "") != "" then "PENDING-PLAN" else "-" end),
         (if .spec.destroy == true then "DESTROY" else "-" end),
         (if .spec.suspend == true then "SUSPENDED" else "-" end)] | @tsv' |
      sort | column -t
    ;;
  down)
    mapfile -t ordered < <(tiers | tac)
    for tier in "${ordered[@]}"; do
      read -r -a objects <<<"${tier}"
      run_tier down "${objects[@]}"
    done
    echo "Runtime is down. Cloud SQL and the global stages are untouched. Rebuild with: runtime.sh ${ENVIRONMENT} up"
    ;;
  up)
    mapfile -t ordered < <(tiers)
    for tier in "${ordered[@]}"; do
      read -r -a objects <<<"${tier}"
      run_tier up "${objects[@]}"
    done
    echo "Runtime is up. openbao starts empty: initialise and unseal it, refresh the floor-openbao-auth secret, then run: runtime.sh ${ENVIRONMENT} config"
    ;;
  config)
    patch "${OPENBAO_CONFIG}" '{"spec":{"suspend":false}}'
    process "${OPENBAO_CONFIG}"
    ;;
  *)
    echo "usage: runtime.sh <environment> <status|down|up|config>" >&2
    exit 2
    ;;
esac
