# Factory platform redesign and bootstrap handoff

## End goal

Build a new, environment-first platform in the Factory monorepo. Replace the Production-only Logos workflow with separate Sandbox, Non-Production, and Production deployment paths. The implementation direction moved from GitHub Actions to **Flux**: start on the local Factory Floor, bootstrap Sandbox first, then hand each environment over to its own execution environment so it can manage itself.

The policy direction is still environment-level baselines with narrowly scoped exceptions where needed. Specific organization policy controls were deliberately deferred. The original Logos design included a team-type hierarchy; the current Factory baseline has **one team** and does not recreate that taxonomy.

| Component | Origin | Responsibility in Factory |
| --- | --- | --- |
| Foundation | Logos | Organization and environment structure, identity, governance, and integrations. The first implementation only creates the Factory folder and publishes metadata. |
| Assembly | Corpus | Projects, networking, DNS, registry, and other infrastructure needed by workloads. |
| Runtime | Pneuma | GKE and its workload platform, including cluster services and execution. |
| Floor | Techne Floor and local integration tooling | Local execution and orchestration across the three components; not another deployment layer or team. |

Use prefix-free Factory-owned names. Foundation, Assembly, and Runtime are not teams; `factory` is the only team. The former Arche repositories supply reusable modules, not a Factory team. Do not bring back legacy team fan-out, `pt-`/`st-` naming, or Datadog integrations. Bootstrap scripts, manifests, and operator skills belong in Factory, not Techne.

## Resume here

Work from the Factory repository root on `bootstrap-sandbox-branch-source`. Do not reset Docker Desktop Kubernetes: the bootstrap depends on cluster-local state. List the Floor objects and pending plans with `bootstrap/seed/runtime.sh sandbox status`, then review with `bootstrap/seed/review.sh` and approve with `bootstrap/seed/approve.sh` using a plan-hash prefix. Approval triggers a cloud apply; review every plan first.

Sandbox status as of 2026-11-22: the seed, Foundation, Assembly and the Runtime stages are applied on both clusters (`us-east1-b` and `us-east4-a`), including cert-manager, istio-csr, multi-region Istio and mesh, OPA Gatekeeper templates, authentik, agentgateway, openbao, `authentik-config` (Google sign-in, groups, applications) and `openbao-config` (OIDC, `kv2`, team policies). See [Runtime](tofu/runtime/README.md) and [STATE-GRAPH.md](STATE-GRAPH.md).

Open items:

- **Unapproved by design:** `opa-gatekeeper-constraints-us-east1-b-sandbox` and `-us-east4-a-sandbox`. Run them last.
- `authentik-config-sandbox` has a pending drift-only plan (group membership added by sign-ins); no resource changes.
- Verify authentik and openbao OIDC sign-in end to end and run an istio-test failover check across regions.
- Local integration applies separate copies of the stage config, so it does not test the real stages ([#6](https://github.com/osinfra-io/factory/issues/6)). This is also why some Sandbox applications lack icons.
- Rename Non-Production to Development ([#5](https://github.com/osinfra-io/factory/issues/5)); not started.
- Scale Runtime to zero while idle ([#3](https://github.com/osinfra-io/factory/issues/3)). There is no automated up/down; see the Runtime README.
- kagent and agent-substrate exist only as modules and local fixtures; pneuma has no equivalent, so they are future work.
- Credentials: the openbao init keys are in `~/secrets/openbao-init-*.json`. The Google OAuth secret lives in the `floor-authentik-google-oauth` secret and the client ID in `tofu/runtime/authentik-config/google.auto.tfvars`. The live Production DNS NS records for `sb` and `nonprod` were corrected and are also committed in `production.tfvars`.

## Work to date

### Legacy design and experiments

- Explored an environment-first hierarchy and separate deployment paths in Logos. The original split exposed a bootstrap problem: Corpus and Core Helpers expected Production Logos state and a Production KMS key before Sandbox could start.
- Prototyped Flux planning and approval on the old Floor, split seed from Foundation, and verified the encrypted seed and Foundation state approach. Explored separate ownership of organization-level Google groups, scoped manager delegation, and keyless runner identities. The old global bootstrap stage was subsequently removed rather than letting environment workspaces duplicate ownership of existing groups.
- The legacy experiment used a different Sandbox root and had its own explicitly approved applies and cleanup. It is not the current Factory environment. Its resource and state status were not rechecked for this handoff. Do not adopt, recreate, or delete legacy resources as part of the current bootstrap; handle any discovered overlap as a separate ownership decision.

### Factory monorepo and local Floor

- Ported the local Docker Desktop integration stack into Factory, including Istio, authentik, agentgateway, Agent Substrate, kagent, OpenBao, and the Flux/tofu-controller Floor. The separate [`factory-floor-fixture`](https://github.com/osinfra-io/factory-floor-fixture) repository is only for exercising the Floor PR workflow, not a cloud deployment source.
- Added Factory-owned instructions and [local integration skill](.github/skills/local-integration-testing/SKILL.md). Reused the imported Arche module implementations under [`tofu/modules`](tofu/modules/), removed duplicate integration-only copies where practical, and split authentik instance-wide configuration from regional deployment/outpost configuration. Removed Datadog from Factory.
- Automated local verification passed on the earlier integration run, including the fixture PR round trip, authorization and recovery behavior, and ambient mTLS. Manual Google browser sign-in verification was not completed; that is separate from the current seed plan review. Do not reset the running cluster to revisit it.

### Current Factory bootstrap branch

- `117d827` added the Factory-owned bootstrap workflow, [seed configuration and preparation script](bootstrap/seed/), and [Flux configuration](floor/config/floors/bootstrap-sandbox/). Sandbox uses the existing GCP folder `567188438944`.
- The seed is intended to create the bootstrap project, enable its required APIs, provision the state bucket and KMS key, and create keyless Assembly and Runtime runner service accounts. That is the intended resource set, not a substitute for checking the exact pending plan. Initial seed state is encrypted and cluster-local; Foundation is configured to start on the seed's GCS/KMS backend.
- `15438e1` added the [minimal Foundation root](tofu/foundation/) and its single [Factory team input](tofu/foundation/teams/factory.tfvars). Foundation creates the Factory folder and publishes team/environment metadata; it does not recreate legacy teams or their integrations.
- `aff604c` fixed a seed planning failure: Flux omitted the Core Helpers symlinks from its source artifact. The root helper now calls the child module directly. The seed subsequently produced a pending plan.
- `331aed2` and `2b3b987` updated the skill to query Floor via `https://floor.localhost/mcp` without a Copilot extension and verify the exact readable plan separately. Floor's workspace response contains plan metadata, not plan contents. Use the skill's read-only identity for review; do not print credentials, raw plans, or state.

## Ordered goals

Steps 1–5 are done for Sandbox. Steps 6–8 are the roadmap, not approval to deploy anything.

1. **Start from the local Floor — done.** Bring up the local Factory stack and publish the bootstrap branch. Stage the seed and Foundation objects and expose the bootstrap namespace through Floor. No CLI extension is required.
2. **Bootstrap the Sandbox seed — done.** Review the live seed plan, obtain explicit human approval for that exact plan, and verify the seed is Ready before using its outputs. No GKE, networking, or workload projects belong in the seed.
3. **Establish Sandbox Foundation.** Once the seed is Ready, prepare the Foundation runner's encrypted backend configuration, review and approve the separate Foundation plan, and verify the Factory folder and metadata. Done.
4. **Build Sandbox Assembly — done.** Use the Sandbox Foundation outputs and encrypted backend to bring over Corpus's project, networking, DNS, registry, identity, team state, and database capabilities. Review main first: the regional workspace cannot plan against its outputs until main has applied. See [Assembly](tofu/assembly/README.md) for the team contract and ownership boundaries.
5. **Build Sandbox Runtime — done except the final verification and the constraints stage.** Once Assembly is verified, use its outputs to provision the Sandbox GKE and workload platform. Validate the runtime's identity, permissions, and readiness; local integration only proves local behavior, not GCP networking or workload identity.
6. **Hand Sandbox reconciliation over to Sandbox.** Establish the in-environment Flux execution and verify it can plan and reconcile its own configuration with scoped credentials. Decide deliberate ownership and state handoff for anything still operated by the local seed. Avoid concurrent ownership; do not assume seed state has migrated.
7. **Repeat for Non-Production, then Production.** Use the proven Sandbox pattern with separate execution, credentials, state, and approvals for each environment. Define the Flux promotion flow and confirm which organization-wide resources are shared rather than duplicated.
8. **Complete cross-environment integration and governance.** Sandbox can create `sb.osinfra.io` without Production. Public DNS delegation is a separate operation owned by the Production `osinfra.io` parent zone; compare the assigned Sandbox and Non-Production nameservers before updating delegation rather than copying old values. Choose concrete organization policies and any exceptions explicitly, then add them under the agreed ownership model.
