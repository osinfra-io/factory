---
sidebar_label: Local development
description: Run the Factory Docusaurus site and opt-in local integration stack.
---

# Local development

Factory has two local development workflows: the Docusaurus documentation site
and an opt-in Docker Desktop integration stack.

## Documentation site

Use Node.js 20 or newer and Yarn Classic. From the repository root:

```bash
cd docusaurus
yarn install --frozen-lockfile
yarn start
```

The local site is available at `http://localhost:3000`. To verify a production
build, run `yarn build` from `docusaurus/`.

## Local integration stack

The integration stack exercises cross-component behavior on a dedicated
Docker Desktop Kubernetes cluster. It is opt-in and is not a CI or pre-push
gate. It verifies local configuration and behavior, not GCP networking,
Workload Identity, or multi-region deployment.

Use only a dedicated cluster with the `docker-desktop` Kubernetes context.
Before setup, provide `TF_VAR_google_oauth_client_id` and
`TF_VAR_google_oauth_client_secret`. The Google OAuth client must allow
`https://localhost/source/oauth/callback/google/`. Set Git's `user.email` to
the Google account used for local sign-in and push the Factory branch so Flux
can fetch it. Setup requires GitHub CLI authentication with access to
`osinfra-io/factory-floor-fixture`; verification needs permission to create,
comment on, and merge pull requests there.

From the repository root, run:

```bash
tests/integration/setup.sh
tests/integration/verify.sh
```

Setup performs ownership and readiness checks. Stop if the cluster contains
resources outside the dedicated Factory fixture; do not adopt or clean up an
unowned cluster. Verification includes a pull-request workflow in the fixture
repository after local checks pass.
Google browser sign-in is a separate manual check, not part of automated
verification.

Full teardown must be performed in the Docker Desktop application. It resets
the entire Kubernetes cluster, not only Factory resources. Do not reset the
cluster during an active bootstrap that depends on cluster-local state.
