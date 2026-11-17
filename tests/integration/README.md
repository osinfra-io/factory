# Local integration tests

An opt-in developer test that runs Authentik, Istio ambient, agentgateway, Agent Substrate, kagent, and OpenBao together on a dedicated Docker Desktop Kind cluster. It is not a CI gate; the module mock tests are run separately.

Factory composes its local modules, so everything cross-cutting lives here: the shared ingress gateway and TLS certificate, browser-auth policies and routes (rendered by the `gateway-auth` module), the diagnostic workload, the ownership marker, and the holistic verifiers.

## Layout

| Path | Purpose |
| --- | --- |
| `setup.sh`, `verify.sh`, `teardown.sh` | Stack entry points: Istio → Authentik → agentgateway → Agent Substrate → kagent → OpenBao (teardown in reverse) |
| `shared/` | Preflight/ownership, cluster guards, and `hostnames.txt` |
| `istio/`, `authentik/`, `agentgateway/`, `agent-substrate/`, `kagent/`, `openbao/` | Per-component fixtures with their own `setup.sh`, `verify.sh`, and `teardown.sh`; OpenBao also applies a local OIDC and team-policy configuration stage |
| `verify/` | Holistic HTTP and runtime (fail-closed, admin denial, ztunnel mTLS) verifiers |

Fixtures use the modules in this repository directly, without release pins. Generated credentials and state live in ignored `.work/` directories while the fixture cluster is owned.

## Usage

```bash
tests/integration/setup.sh
tests/integration/verify.sh
tests/integration/teardown.sh        # deletes local users and database data
```

Before setup, set `TF_VAR_google_oauth_client_id` and `TF_VAR_google_oauth_client_secret`. The Google web client must allow `https://localhost/source/oauth/callback/google/`.

On first setup, preflight checks that the `docker-desktop` Kind cluster has no non-system namespaces, Helm releases, or gateway/mesh CRDs, then records ownership automatically. If those checks pass, stale component `.work/` directories are removed before setup; this deletes local state and generated credentials, so provide OAuth variables again. Preflight preserves `.work/` on an already-owned cluster and refuses an unowned cluster that is not empty.

Component scripts can be rerun individually (for example `tests/integration/authentik/setup.sh`) while iterating.

- The `floor` component installs the floor engine off the ambient mesh in `flux-system`: the Flux Operator, a `FluxInstance` running source, kustomize, and notification controllers, and tofu-controller with its Branch Planner scoped to the `floor-fixture` namespace. It deploys `floor-api`, the Go MCP server behind `floor.localhost`, as the only writer of plan approvals. The Floor config is reconciled from this repository's current branch, so push that branch before setup; its GitHub PR verification uses the external `osinfra-io/factory-floor-fixture` repository. It requires the `gh` CLI and a token that can read pull requests, comment on them, and merge with admin bypass on that fixture repository. `verify.sh` opens and merges a pull request there on every run.

The OpenBao setup applies its fixture-owned OIDC and KV v2 configuration using the local Authentik outputs and credentials under `.work/`. It seeds a README under the local `factory` team key and lets each team role list the top-level team names; secret values remain team-scoped. Automated verification checks OIDC settings, reader/writer/admin capabilities, top-level team listing, and cross-team denial; it uses short-lived test tokens and never prints them.

Google-backed OIDC sign-in is a separate manual developer check and is not covered by the automated verifier:

1. Open `https://openbao.localhost/ui/`, choose the OIDC login method, and complete the Google sign-in through Authentik.
2. Use the CLI callback flow with a browser-enabled terminal:

   ```bash
   BAO_CACERT="$PWD/tests/integration/istio/.work/gateway-localhost.crt" \
   BAO_ADDR=https://openbao.localhost \
   bao login -method=oidc -path=oidc role=default
   ```

3. Optionally set `TF_VAR_local_test_user_email` to a lowercase Google email before setup to add that user to local application groups. Verify team-scoped access after sign-in. Automated policy checks do not prove that Google sign-in or group claims work end to end.

The local fixture uses the same host-level authorization as the cloud: `agentgateway.localhost` requires the managed agentgateway Admins group, `kagent.localhost` requires kagent Admins, while `dev.localhost` uses the baseline `all` group. No post-auth authorization Lua is deployed; only identity-header stripping remains.

Google users are classified as internal only when their verified email and Google Workspace `hd` claim both match `osinfra.io`; other Google users remain external. Existing accounts receive the classification on their next Google sign-in. Internal status permits access to the authentik user interface, but administrative permissions still require the declared authentik Admins group.

The shared `gateway-auth` module always exempts standard health and readiness paths, so removing `/istio-test/health` from `public_paths` does not make that endpoint protected. For configuration-parity checks, use a metadata endpoint such as `https://dev.localhost/istio-test/metadata/cluster-name` with the HTTP verifier's `--expect-status` mode.

To verify membership changes without regenerating gateway configuration, sign in at `https://agentgateway.localhost/ui/` with a declared member, then apply only the Authentik configuration with the revocation flag:

```bash
bash tests/integration/authentik/set-application-access.sh revoke
```

The helper checks fixture ownership, opens a temporary loopback admin port-forward, and uses the same provider directory, state, and variable files as setup. The existing session can retain its cached authorization for up to ten minutes plus one second. A fresh session should be denied immediately; diagnostic access at `dev.localhost` is unaffected. Restore the declared memberships with `bash tests/integration/authentik/set-application-access.sh restore`; neither apply changes gateway configuration. This expiry bound is derived from outpost session handling and still requires live browser verification.

See the `local-integration-testing` skill for cluster ownership and manual Google sign-in requirements.

## Hostnames and certificate

`shared/hostnames.txt` is the single list of local gateway hosts. The gateway certificate's subject alternative names are generated from it (plus bare `localhost` for the Google OAuth callback), and the HTTP verifier's allowlist reads it. Adding a component host means editing this list and its route, with no change in any module repository.

A wildcard `*.localhost` SAN was not used because browsers may reject wildcards directly under a single-label TLD.
