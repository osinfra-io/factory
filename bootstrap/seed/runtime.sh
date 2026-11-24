#!/usr/bin/env bash

# Tear down or rebuild the Runtime for an environment through the Floor, one reviewed plan at a time.
# Usage: runtime.sh <environment> <status|down|destroy|up|config>
#
#   status  list Runtime objects, pending plans, and destroy/suspend flags
#   down    fast: suspend the zonal objects, delete the clusters, stop Cloud SQL, drop their state
#   destroy graceful: destroy every zonal Runtime object through reviewed plans, dependents first
#   up      start Cloud SQL, then recreate the objects in dependency order
#   config  reconcile openbao-config; run after openbao is initialised and unsealed
#
# `down` skips per-stage destroys because deleting the clusters removes everything inside them.
# Every plan is shown and approved only when its hash prefix is typed back; nothing is approved
# automatically. The in-cluster stages are destroyed through the controller's `spec.destroy`
# flag, and the two configuration stages are suspended while the clusters are gone, so
# Assembly (projects, network, DNS, Cloud SQL) and the global stages keep their state.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENVIRONMENT="${1:?usage: runtime.sh <environment> <status|down|destroy|up|config>}"
COMMAND="${2:?usage: runtime.sh <environment> <status|down|destroy|up|config>}"
NAMESPACE="bootstrap-${ENVIRONMENT}"
OPENBAO_CONFIG="openbao-config-${ENVIRONMENT}"
CONFIG_OBJECTS=("authentik-config-${ENVIRONMENT}" "${OPENBAO_CONFIG}")
PROJECT_SUFFIX="${ENVIRONMENT/sandbox/sb}"
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
      patch "${object}" '{"spec":{"destroy":false,"suspend":false}}'
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

is_zonal() {
  ! is_config "$1" && [[ "$1" =~ -us-[a-z]+[0-9]-[a-z]-"${ENVIRONMENT}"$ ]]
}

state_bucket() {
  "${kube[@]}" get configmap foundation-bootstrap-backend -o jsonpath='{.data.bucket}'
}

runtime_project() {
  gcloud projects list --format='value(projectId)' | grep -E "^factory-.*-${PROJECT_SUFFIX}$" | head -1
}

case "${COMMAND}" in
  down)
    project="$(runtime_project)"
    [ -n "${project}" ] || { echo "Runtime project not found." >&2; exit 1; }
    bucket="$(state_bucket)"
    mapfile -t objects < <("${kube[@]}" get terraform -o name | sed 's|.*/||' | grep -E -- "-${ENVIRONMENT}$")
    echo "Suspending Runtime objects."
    for object in "${objects[@]}"; do
      if is_config "${object}" || is_zonal "${object}"; then
        patch "${object}" '{"spec":{"destroy":false,"suspend":true}}'
      fi
    done
    echo "Stopping Cloud SQL and deleting clusters in ${project}."
    gcloud sql instances list --project "${project}" --format='value(name)' |
      xargs -r -I{} gcloud sql instances patch {} --project "${project}" --activation-policy=NEVER --quiet
    gcloud container clusters list --project "${project}" --format='value(name,location)' |
      while read -r name location; do
        gcloud container clusters delete "${name}" --location "${location}" --project "${project}" --quiet &
      done
    wait
    echo "Dropping state for the zonal stages."
    gcloud storage ls "gs://${bucket}/runtime/" | grep -E -- "/us-[a-z]+[0-9]-[a-z]-.*-${ENVIRONMENT}\.tfstate$" |
      xargs -r gcloud storage rm
    echo "Runtime is down. Assembly and the global stages are untouched. Rebuild with: runtime.sh ${ENVIRONMENT} up"
    ;;
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
  destroy)
    mapfile -t ordered < <(tiers | tac)
    for tier in "${ordered[@]}"; do
      read -r -a objects <<<"${tier}"
      run_tier down "${objects[@]}"
    done
    echo "Runtime is down. Cloud SQL and the global stages are untouched. Rebuild with: runtime.sh ${ENVIRONMENT} up"
    ;;
  up)
    project="$(runtime_project)"
    gcloud sql instances list --project "${project}" --format='value(name)' |
      xargs -r -I{} gcloud sql instances patch {} --project "${project}" --activation-policy=ALWAYS --quiet
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
    echo "usage: runtime.sh <environment> <status|down|destroy|up|config>" >&2
    exit 2
    ;;
esac
