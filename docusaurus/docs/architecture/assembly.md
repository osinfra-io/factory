---
sidebar_label: Assembly
description: Assembly's current main and regional infrastructure responsibilities.
---

# Assembly

Assembly composes the cloud infrastructure required by an environment and its
teams. Its OpenTofu roots are `tofu/assembly/` and `tofu/assembly/regional/`.

## Main workspace

The main workspace reads Foundation state and owns environment-level resources,
including:

- Shared VPC host and team/workload projects
- Public and private DNS zones and team DNS delegations
- Container registry repositories and publishing identities
- Private services access and state-storage resources

Team capabilities are requested through the shared team tfvars. An absent team
request does not provision that optional capability.

## Regional workspaces

Regional workspaces read the main Assembly outputs. They create subnet pairs,
secondary address ranges, NAT, subnet IAM, and private Cloud SQL instances and
their DNS records. Runtime consumes the regional `runtime_networks` outputs to
create GKE clusters.

The Sandbox Floor configuration contains the main workspace and regional
workspaces for `us-east1` and `us-east4`. Non-Production and Production also
have inputs and regional overlays; those overlays configure their regional
workspaces to apply after approval.

Environment DNS domains are `sb.osinfra.io` for Sandbox,
`nonprod.osinfra.io` for Non-Production, and `osinfra.io` for Production. The
Production-owned parent zone must publish the verified Sandbox and
Non-Production nameservers for public delegation.
