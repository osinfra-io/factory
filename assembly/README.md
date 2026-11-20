# Assembly

Assembly takes over Corpus's infrastructure responsibilities. The main workspace
reads its environment's Foundation state. It owns projects, the Shared VPC, DNS zones,
registry, publishing identities, encrypted team state, and private services
peering. The regional workspace owns subnet pairs, secondary IP ranges, NAT,
subnet IAM, and private Cloud SQL and its DNS records. GKE belongs to Runtime,
which consumes the regional `runtime_networks` output.

Assembly owns the shared host project, VPC, environment DNS, and the Docker
Hub remote. Those resources are not team inputs. Assembly creates one shared
Docker Hub remote when any team requests a registry.

Teams use their normal [team tfvars](../foundation/teams/factory.tfvars) to
request team capabilities. There is no `assembly` block. An absent team
request does not provision that team capability.

| Team field | Capability |
| --- | --- |
| `google_project` | Team-managed project with baseline services, central logging, a budget, optional extra APIs, and project-scoped editors. |
| `workload_project` | Platform-managed workload project and Shared VPC attachment. Its optional `kubernetes_engine` block requests subnet pairs using each location's CIDRs and a delegated team DNS zone. Its `cloud_sql` map requests private instances with region-specific DNS names. |
| `artifact_registry` | Request a standard push and virtual pull repository pair and configure access. Assembly wires the shared Docker Hub remote. A fleet host's virtual repository includes configured member-cluster pull principals. |

Every onboarded team gets a versioned OpenTofu state bucket with a dedicated
KMS key. Teams do not opt in or choose reader and writer grants. The platform
provisions runner access separately, scoped to the team's backend.

[Platform inputs](environments/) per environment own billing, budgets,
the Private Service Access CIDR, external Shared VPC attachments, trusted GitHub organization ID,
Runtime project IAM, and the optional `gke_fleet_host` selection from among
requested cluster locations. The Shared VPC reserves the CIDR and connects to
Private Service Access whether or not a team requests Cloud SQL.
When configured, GitHub OIDC grants registry publishing
for specific numeric repository IDs; it does not grant infrastructure
deployment, billing, or backend access. Floor owns deployment. Team backend
access does not grant access to Foundation or Assembly state. The Production parent zone
still owns delegation of `sb.osinfra.io` and `nonprod.osinfra.io`; it can use the main `public_dns` output
after a reviewed Sandbox apply. Assembly does not adopt legacy resources.

The Sandbox bootstrap created the shared host project and network and the
Factory team's versioned, KMS-encrypted state bucket. The shared host and Factory
workload projects belong under `Sandbox / Factory`. Factory's team tfvars
now request Assembly networking in three zones each in `us-east1` and `us-east4`,
using Pneuma's former CIDRs. Private Cloud SQL for authentik is disabled for now.
Sandbox selects Factory's `us-east1-b` cluster as the shared GKE fleet host.
The registry group declarations do not provision groups or enable the registry pair.
GKE itself is managed by Runtime, and Factory will request its registry pair
when Runtime is onboarded. The seed remains on cluster-local state, and
Foundation and Assembly still use the seed project's backend. Moving those
states is a separate handoff after the destination exists and runner access
has been configured.

The shared host and Factory workload project IDs both follow `factory-tfXXX-sb`:
the team key is the prefix, and each project gets its own three random
hexadecimal digits at apply time. Floor defines `us-east1` and `us-east4` regional workspaces
for Sandbox, Non-Production, and Production. Only Sandbox is wired into the
current Floor deployment. Include the matching
[regional overlay](../floor/config/floors/assembly-regional/) when bringing up
Non-Production or Production. Each overlay needs its own `bootstrap-<env>`
namespace, runner credentials, `foundation-source`, and backend ConfigMaps.
Its `assembly-<env>` dependency must publish `assembly-main-<env>` state
under the `assembly` backend prefix.

Sandbox main and regional workspaces apply only after manual approval of their
exact plans. Regional workspaces wait for their own environment's main Assembly
outputs. The Non-Production and Production regional overlays remain plan-only.

Run the mocked tests from the repository root without cloud credentials:

```shell
TF_WORKSPACE=assembly-main-sandbox tofu -chdir=assembly test \
  -var-file=environments/sandbox.tfvars -var-file=../foundation/teams/factory.tfvars
TF_WORKSPACE=us-east1-assembly-sandbox tofu -chdir=assembly/regional test
```

Environment DNS domains are `sb.osinfra.io`, `nonprod.osinfra.io`, and `osinfra.io`
(Production, the parent zone). Non-Production and Production Assembly code and inputs
exist, but their seed and Foundation are not yet bootstrapped.
