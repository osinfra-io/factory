---
name: local-integration-testing
description: Run or troubleshoot Factory's opt-in local integration stack on Docker Desktop Kubernetes. Full teardown must be performed in the Docker Desktop application.
---

# Run Factory local integration

This is an opt-in developer test for changes that cross component boundaries, not a pre-push check or CI gate. Run commands from the Factory repository root so fixtures use the checked-out modules. The stack validates local configuration and behavior, not GCP networking, Workload Identity, or multi-region deployment. Never read or search `.terraform/`.

## Setup

Set `TF_VAR_google_oauth_client_id` and `TF_VAR_google_oauth_client_secret`. The authentik fixture requires both; its Google web client must allow:

```text
https://localhost/source/oauth/callback/google/
```

The Floor fixture also requires `gh auth login` with access to `osinfra-io/factory-floor-fixture`. Flux reads the Factory branch selected by `FLOOR_CONFIG_REF` (the current checkout branch by default), so push that branch before setup.

Use `tests/integration/setup.sh` as the prerequisite gate and setup entry point; it checks credentials and branch access, then invokes `tests/integration/shared/preflight.sh` for local tools and cluster readiness before installing components. Do not manually probe those prerequisites first. The shared preflight script is not read-only: on a qualifying unowned cluster it records ownership and clears component `.work` directories, so do not run it standalone as a harmless check.

Run:

```bash
tests/integration/setup.sh
```

Preflight requires the current `docker-desktop` context and Docker Desktop Kind. It reuses an existing matching ownership marker, or, if the cluster is unowned and passes its emptiness checks, records ownership and clears the seven component `.work` directories before setup. Those checks reject non-system namespaces, workloads in `default`, Helm releases, and gateway/mesh CRDs; they do not inventory every resource kind or objects in system namespaces. Use only a dedicated cluster, and stop if you know it contains other resources. Clearing `.work` removes stale local state and credentials after a cluster reset, so supply the Google OAuth variables again. An already-owned cluster keeps its `.work` data. If preflight finds any of the checked resources or a foreign ownership marker, stop rather than adopting or removing them.

Agent Substrate setup automatically enables its required certificate APIs and kubelet feature gates. This requires a dedicated single-node Docker Desktop cluster. The helper restarts the kubelet and updates the API-server manifest only when configuration changes are needed. It uses temporary files under host `.work` and node `/var/tmp` and does not create backups. If the update fails, reset Docker Desktop Kubernetes before retrying.

Setup runs Istio, authentik, gateway policy/routes, agentgateway, Agent Substrate, kagent, OpenBao, and Floor in dependency order. To iterate, rerun only the affected component's `setup.sh` (or `istio/apply-auth.sh` / `istio/apply-routes.sh`). Do not reset the cluster between ordinary edits.

authentik setup uses `git config user.email` as the local test identity. It must match the Google account used for sign-in. The identity is added to every configured sandbox application group, including `factory: Authentik Admins`, a superuser group; use only the disposable local fixture.

## Automated verification

Run:

```bash
tests/integration/verify.sh
```

It checks component health, gateway routes and authorization, forged identity headers, fail-closed behavior and recovery, ambient mTLS, and the Floor PR workflow. It stops on failure and leaves the stack running. If recovery fails, report it and stop; do not continue as if verification passed.

Setup does not run the Floor PR check. Verification runs it last, after the local checks pass. It creates and updates a branch, opens a pull request in `osinfra-io/factory-floor-fixture`, exercises planning and approval, then squash-merges under the repository's normal rules. It requires a GitHub token with permission to write repository contents and create, comment on, and merge pull requests. A request to run verification includes this fixture workflow; do not prompt separately. On failure before merge, cleanup attempts to close the pull request and delete its branch.

For a policy-change check, apply the change with its owning script, then use the HTTP verifier's bounded status mode to wait for the expected status. This command only observes HTTP behavior; it does not apply or restore policy:

```bash
python3 tests/integration/verify/verify-http.py --expect-status 302 --timeout 120 \
  https://dev.localhost/istio-test/metadata/cluster-name
```

After restoring the policy with its owning script, run the verifier again for the original status (normally `200` for this public metadata endpoint).

## Google and browser checks

Automated verification does not complete Google browser sign-in. Leave fixtures running and use:

```text
https://dev.localhost/istio-test/auth
https://agentgateway.localhost/agentgateway-test/auth
https://agentgateway.localhost/ui/
https://kagent.localhost/
https://authentik.localhost/
https://openbao.localhost/ui/
```

Accept the local certificate warning and sign in through Google using the account matching `git config user.email`. Verify the diagnostic paths identify the signed-in user and forged identity headers are ignored. Do not retain personal identity output.

To test membership changes, use only a disposable local test identity. The fixture helper temporarily empties every configured sandbox application group; `restore` reapplies the configured memberships:

```bash
bash tests/integration/authentik/set-application-access.sh revoke
# Verify a fresh browser session is denied access to the protected application.
bash tests/integration/authentik/set-application-access.sh restore
```

An existing proxy session may retain cached authorization for up to ten minutes plus one second. Use a fresh session after revoking and again after restoring; diagnostic access at `dev.localhost` remains available.
Restore membership before rerunning automated verification, which expects normal access for the local test identity.

For OpenBao, choose **OIDC** in the UI with role `default`. From the repository root, the CLI can use the fixture certificate:

```bash
BAO_CACERT="$PWD/tests/integration/istio/.work/gateway-localhost.crt" \
BAO_ADDR=https://openbao.localhost \
bao login -method=oidc -path=oidc role=default
```

Ensure `openbao.localhost` and `authentik.localhost` resolve to the gateway and the browser can reach the CLI callback at `http://localhost:8250/oidc/callback`.

If browser sign-in cannot be completed, report **automated checks passed; Google browser verification pending** only when `tests/integration/verify.sh` passed. Include the URLs and remaining manual checks; do not claim full integration success.

## Full teardown

WSL cannot reset Docker Desktop Kubernetes. Ask the user to confirm they want a full cluster reset, then direct them to reset the Kubernetes cluster in the Docker Desktop application. This removes every cluster resource, not just Factory fixtures. Do not run CLI or per-component teardown commands, and do not claim teardown is complete until the user confirms the reset.
