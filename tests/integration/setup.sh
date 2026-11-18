#!/usr/bin/env bash

# Sets up the whole local gateway stack on Docker Desktop Kind.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

if [ "$#" -ne 0 ]; then
  echo "Usage: setup.sh" >&2
  exit 2
fi

for tool in git gh; do
  if ! command -v "${tool}" >/dev/null; then
    echo "Missing local integration prerequisite: ${tool}" >&2
    exit 1
  fi
done

if [ -z "${TF_VAR_google_oauth_client_id:-}" ] || [ -z "${TF_VAR_google_oauth_client_secret:-}" ]; then
  echo "Set TF_VAR_google_oauth_client_id and TF_VAR_google_oauth_client_secret; full integration requires real Google sign-in." >&2
  exit 1
fi

if [ -z "$(git -C "${SCRIPT_DIR}/../.." config user.email || true)" ]; then
  echo "Set git config user.email to the Google account used for local sign-in." >&2
  exit 1
fi

if ! gh auth token >/dev/null; then
  echo "No GitHub token is available; run 'gh auth login' with access to osinfra-io/factory-floor-fixture." >&2
  exit 1
fi

floor_config_repo="${FLOOR_CONFIG_REPO:-https://github.com/osinfra-io/factory}"
floor_config_ref="${FLOOR_CONFIG_REF:-$(git -C "${SCRIPT_DIR}/../.." branch --show-current)}"
if [ -z "${floor_config_ref}" ]; then
  echo "Set FLOOR_CONFIG_REF when the Factory checkout has no current branch." >&2
  exit 1
fi
if ! GIT_TERMINAL_PROMPT=0 git ls-remote --exit-code --heads "${floor_config_repo}" "${floor_config_ref}" >/dev/null; then
  echo "Cannot find Floor configuration branch '${floor_config_ref}' in '${floor_config_repo}'; push it or check repository access." >&2
  exit 1
fi

"${SCRIPT_DIR}/shared/preflight.sh"

# Kubernetes manifest providers need CRDs at plan time, so each component is a separate stage.
"${SCRIPT_DIR}/istio/setup.sh"
"${SCRIPT_DIR}/authentik/setup.sh"
"${SCRIPT_DIR}/istio/apply-auth.sh"
"${SCRIPT_DIR}/istio/apply-routes.sh"
"${SCRIPT_DIR}/agentgateway/setup.sh"
"${SCRIPT_DIR}/agent-substrate/setup.sh"
"${SCRIPT_DIR}/kagent/setup.sh"
"${SCRIPT_DIR}/openbao/setup.sh"
"${SCRIPT_DIR}/floor/setup.sh"

echo "Local gateway stack is ready. Run tests/integration/verify.sh, then complete Google sign-in manually."
