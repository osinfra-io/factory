#!/usr/bin/env bash

# Copy the applied seed's cluster-local state into the environment's own GCS state
# bucket, re-encrypted with the environment's KMS key, then verify it plans clean.
# Usage: migrate-state.sh <environment>
#
# The cluster Secret is left untouched, so the migration can be repeated safely.
# Afterwards the seed's Terraform object must use the gcs backend; see the printed steps.

set -euo pipefail
set +x
umask 077

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ENVIRONMENT="${1:?usage: migrate-state.sh <environment>}"

case "${ENVIRONMENT}" in
  sandbox) FOLDER_ID=567188438944 ENV_SHORT=sb ;;
  non-production) FOLDER_ID=851025769053 ENV_SHORT=nonprod ;;
  production) FOLDER_ID=1093631952702 ENV_SHORT=prod ;;
  *) echo "usage: migrate-state.sh [sandbox|non-production|production]" >&2; exit 1 ;;
esac

STAGE="bootstrap-${ENVIRONMENT}"
SEED_PROJECT="bootstrap-${FOLDER_ID}-${ENV_SHORT}"
BUCKET="${SEED_PROJECT}-state"
WORKSPACE="${STAGE}"
WORK_DIR="${REPO_DIR}/.work/${STAGE}"
MIGRATE_DIR="${WORK_DIR}/migrate"
kube=(kubectl --context=docker-desktop --namespace="${STAGE}")

[ "$("${kube[@]}" get terraform "${STAGE}" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')" = "True" ] ||
  { echo "The seed must be applied (Ready) before its state is migrated." >&2; exit 1; }

passphrase="$(sed -n 's/^ *passphrase = "\(.*\)"$/\1/p' "${WORK_DIR}/encryption.hcl")"
[ -n "${passphrase}" ] || { echo "Missing the local seed encryption key in ${WORK_DIR}/encryption.hcl." >&2; exit 1; }
kms_key="$(gcloud kms keys describe default --keyring=state-encryption --location=us \
  --project="${SEED_PROJECT}" --format='value(name)')"

rm -rf "${MIGRATE_DIR}"
mkdir -p "${MIGRATE_DIR}"
# An override file switches the seed root's backend without changing its source.
OVERRIDE="${SCRIPT_DIR}/backend_override.tofu"
trap 'rm -f "${OVERRIDE}"' EXIT

# The new key encrypts everything written; the old key only reads the cluster copy.
TF_ENCRYPTION="$(
  cat <<HCL
key_provider "pbkdf2" "default" {
  passphrase = "${passphrase}"
}
key_provider "gcp_kms" "kms" {
  key_length         = 32
  kms_encryption_key = "${kms_key}"
}
method "aes_gcm" "old" {
  keys = key_provider.pbkdf2.default
}
method "aes_gcm" "new" {
  keys = key_provider.gcp_kms.kms
}
state {
  method = method.aes_gcm.new
  fallback {
    method = method.aes_gcm.old
  }
}
plan {
  method = method.aes_gcm.new
  fallback {
    method = method.aes_gcm.old
  }
}
HCL
)"
export TF_ENCRYPTION
unset passphrase

GOOGLE_OAUTH_ACCESS_TOKEN="$(gcloud auth application-default print-access-token)"
export GOOGLE_OAUTH_ACCESS_TOKEN
export TF_WORKSPACE="${WORKSPACE}"
export TF_IN_AUTOMATION=1
export TF_DATA_DIR="${MIGRATE_DIR}/.data"
tofu_seed() { tofu -chdir="${SCRIPT_DIR}" "$@"; }

# Stage the cluster copy in a local backend, then migrate it to GCS so the encryption
# fallback re-encrypts it with the KMS key.
cat >"${OVERRIDE}" <<TOFU
terraform {
  backend "local" {
    workspace_dir = "${MIGRATE_DIR}/states"
  }
}
TOFU
mkdir -p "${MIGRATE_DIR}/states/${WORKSPACE}"
"${kube[@]}" get secret "tfstate-${WORKSPACE}-${STAGE}" -o jsonpath='{.data.tfstate}' |
  base64 --decode | gzip --decompress --stdout >"${MIGRATE_DIR}/states/${WORKSPACE}/terraform.tfstate"
tofu_seed init -input=false -reconfigure >/dev/null

cat >"${OVERRIDE}" <<'TOFU'
terraform {
  backend "gcs" {}
}
TOFU
tofu_seed init -input=false -migrate-state -force-copy \
  -backend-config="bucket=${BUCKET}" -backend-config="prefix=bootstrap" >/dev/null
rm -rf "${MIGRATE_DIR}/states"

plan_status=0
tofu_seed plan -input=false -lock-timeout=60s -detailed-exitcode >"${MIGRATE_DIR}/plan.log" 2>&1 || plan_status=$?
case "${plan_status}" in
  0) echo "State migrated to gs://${BUCKET}/bootstrap and verified: no changes." ;;
  2) echo "State migrated, but the plan shows changes; review ${MIGRATE_DIR}/plan.log before switching backends." >&2; exit 1 ;;
  *) echo "Plan failed after migration; see ${MIGRATE_DIR}/plan.log." >&2; exit 1 ;;
esac

cat <<EOF
Next, point ${STAGE} at the migrated state in floor/config/floors/${STAGE}/terraform.yaml:
  backendConfig.customConfiguration: backend "gcs" {}
  backendConfigsFrom: a ConfigMap with bucket=${BUCKET} and prefix=bootstrap
  runner env secret: floor-foundation-state-env (KMS) instead of floor-bootstrap-state-env
Commit, push, and confirm the object plans with no changes. Then delete the cluster state Secrets.
EOF
