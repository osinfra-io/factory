# Sandbox Assembly

Assembly takes over Corpus's infrastructure responsibilities. The main workspace
reads the Sandbox Foundation state. It owns projects, the Shared VPC, DNS zones,
registry, publishing identities, encrypted team state, and private services
peering. The regional workspace owns subnet pairs, secondary IP ranges, NAT,
subnet IAM, and private Cloud SQL and its DNS records. GKE belongs to Runtime,
which consumes the regional `runtime_networks` output.

Teams use their normal [team tfvars](../foundation/teams/factory.tfvars). There is
no `assembly` block. An absent request does not provision that capability.

| Team field | Capability |
| --- | --- |
| `google_project` | Team-managed project with baseline services, central logging, a budget, optional extra APIs, and project-scoped editors. |
| `kubernetes_engine` | Managed workload project, Shared VPC attachment, subnet pairs per requested zone, a delegated team zone, optional DNS record writers, and optional fleet host support. |
| `artifact_registry` | Standard push and virtual pull repositories backed by the team's standard repository and a shared Docker Hub remote. A fleet host's virtual repository includes configured member-cluster pull principals. |
| `cloud_sql` | Private SQL instances in the requested regions, with a region-specific DNS name for each instance. |
| `opentofu_state` | Versioned GCS bucket with a dedicated KMS key and separate reader and writer grants. |

[Sandbox platform inputs](environments/sandbox.tfvars) own billing, budgets, address
allocations, external Shared VPC attachments, trusted GitHub organization ID,
and Runtime project IAM. When configured, GitHub OIDC grants registry publishing
for specific numeric repository IDs; it does not grant infrastructure
deployment, billing, or backend access. Floor owns deployment. Team state grants
do not grant access to Foundation or Assembly state. The Production parent zone
still owns delegation of `sb.osinfra.io`; it can use the main `public_dns` output
after a reviewed Sandbox apply. Assembly does not adopt legacy resources.

The first Sandbox plan proposes the shared host project and network, Docker
repositories, and the Factory team's versioned, KMS-encrypted state bucket. It
does not create a workload project or GKE. Registry and state access grants
require explicit principals. The seed remains on cluster-local state, and
Foundation and Assembly still use the seed project's backend. Moving those
states is a separate handoff after the destination exists and runner access
has been configured.

The host ID follows `factory-tfXXX-sb`: the team
key is the prefix, and three random hexadecimal digits are assigned at apply
time. The `us-east1-b` address allocations are reserved for when the Factory
team requests GKE. The `us-east1` regional
workspace is configured in Floor; register a separate workspace before requesting
infrastructure in another region. Both Sandbox workspaces are plan-only. Main
must publish its outputs before a live regional plan can run.

Run the mocked tests from the repository root without cloud credentials:

```shell
TF_WORKSPACE=assembly-main-sandbox tofu -chdir=assembly test \
  -var-file=environments/sandbox.tfvars -var-file=../foundation/teams/factory.tfvars
TF_WORKSPACE=us-east1-assembly-sandbox tofu -chdir=assembly/regional test
```
