---
name: tofu-module-component-versions
description: Check or update upstream versions pinned by Factory's Kubernetes modules. Use when asked to check or update Istio, cert-manager, cert-manager istio-csr, or OPA Gatekeeper versions.
---

# Update module component versions

Update component version defaults directly in Factory's `tofu/modules/` tree. Do not create per-module branches or pull requests, tag releases, or propagate module source pins.

## Version registry

| Component | Module variable | Local file(s) | Upstream repository | Stored format |
| --- | --- | --- | --- | --- |
| cert-manager | `cert_manager_version` | `tofu/modules/kubernetes/cert-manager/regional/variables.tofu` | `cert-manager/cert-manager` | Strip leading `v` |
| cert-manager istio-csr | `cert_manager_istio_csr_version` | `tofu/modules/kubernetes/cert-manager/regional/istio-csr/variables.tofu` | `cert-manager/istio-csr` | Strip leading `v` |
| Istio | `istio_version` | `tofu/modules/kubernetes/istio/shared/versions.tofu` | `istio/istio` | Strip leading `v` |
| OPA Gatekeeper | `gatekeeper_version` | `tofu/modules/kubernetes/opa-gatekeeper/regional/variables.tofu` | `open-policy-agent/gatekeeper` | Keep leading `v` |

## Check versions

Read each current default from its variable declaration and query the latest upstream GitHub release:

```bash
rg -n -A5 'variable "(cert_manager_version|cert_manager_istio_csr_version|istio_version|gatekeeper_version)"' tofu/modules/kubernetes --glob '!**/.terraform/**'

gh release view --repo cert-manager/cert-manager --json tagName --jq '.tagName | ltrimstr("v")'
gh release view --repo cert-manager/istio-csr --json tagName --jq '.tagName | ltrimstr("v")'
gh release view --repo istio/istio --json tagName --jq '.tagName | ltrimstr("v")'
gh release view --repo open-policy-agent/gatekeeper --json tagName --jq '.tagName'
```

If asked to check, report `Component | Variable | Current | Latest | Update?` rows and do not edit files. If an upstream query fails, report the error and do not guess a version.

## Update and validate

If asked to update, change only outdated defaults in the listed local files. Do not change chart configuration or unrelated module inputs.

Run formatting on the changed files:

```bash
tofu fmt -check \
  tofu/modules/kubernetes/cert-manager/regional/variables.tofu \
  tofu/modules/kubernetes/cert-manager/regional/istio-csr/variables.tofu \
  tofu/modules/kubernetes/istio/shared/versions.tofu \
  tofu/modules/kubernetes/opa-gatekeeper/regional/variables.tofu
```

Run `tofu test` from each affected module root that has tests:

```bash
(cd tofu/modules/kubernetes/cert-manager && tofu test)
(cd tofu/modules/kubernetes/istio && tofu test)
(cd tofu/modules/kubernetes/opa-gatekeeper && tofu test)
```

Only test modules whose defaults changed. These are mocked module tests; do not run the local Kubernetes integration stack for a version-only update. Review the diff to confirm it changes only intended defaults. Summarize changed variables with old and new values and report the checks performed.
