---
applyTo: "**"
---

# Factory Instructions

## Architecture

Factory is an open-source Infrastructure as Code factory. Its three layers are:

- **Foundation** establishes organizational foundations, identity, integrations, and governance.
- **Assembly** composes and provisions cloud infrastructure, projects, environments, and resources.
- **Runtime** provides the execution environment and workload capabilities.

**Floor** is the local execution and orchestration environment for Factory. It operates across the layers and is not a fourth layer.

## Repository Layout

- Reusable OpenTofu modules live under `tofu/modules/<domain>/<module>`.
- Cross-component local integration tests and their scripts live under `tests/integration/`.
- Copilot instructions and skills are maintained under `.github/`.
- Ignore every `.terraform/` directory; it contains downloaded provider and module artifacts.

## Engineering Principles

- Build a clear reference architecture, not a production system whose deployed behavior must be preserved at all costs.
- Prefer simple, explicit, maintainable implementations.
- Make focused changes and avoid speculative abstractions.
- Do not add Datadog integrations to Factory.
- Use lowercase `authentik` and `agentgateway` in prose, headings, comments, and user-facing messages. Preserve exact casing in API names, code identifiers, and configured names.

## Team Configuration

- Use team tfvars as the source of truth for team-owned configuration across Foundation, Assembly, and Runtime.
- Local integration tests must use the same team declarations and deployment code as the target environment. Do not copy team configuration into fixtures. Override only local execution details and disposable test identities.
- Keep secrets and environment bootstrap inputs separate from team tfvars.

## OpenTofu Conventions

Modules follow this standard file layout:

| File | Purpose |
| --- | --- |
| `main.tofu` | Resource and module declarations |
| `variables.tofu` | Inputs, descriptions, types, and validation |
| `outputs.tofu` | Described outputs |
| `locals.tofu` | Transformations and computed values |
| `helpers.tofu` | Shared helper-module invocation |
| `providers.tofu` | Provider configuration |
| `backend.tofu` | State backend configuration |
| `data.tofu` | Data sources |
| `moved.tofu` | Resource address changes |

Use local relative paths for dependencies between modules in this repository. When identical files are needed in sibling directories, keep one canonical copy in the nearest `shared/` directory and use relative symlinks.

Floor is the exception: Flux Git source artifacts omit symlinks. Deployment-consumed OpenTofu files must be regular files. Keep shared copies listed in `tests/check_shared_files.py`, edit their canonical sources, and regenerate them with `python3 tests/check_shared_files.py --sync`. The `shared-files` pre-commit hook checks synchronization and rejects deployment-source symlinks; test fixtures may still use symlinks.

Keep all conditional logic, string transformations, and computed values in `locals.tofu`. The only inline exception is a single-function type conversion with no conditional or string logic, such as `toset(var.names)` or `jsonencode(var.config)`.

Ordering and formatting:

- Keep variables, outputs, locals, and `.tfvars` entries alphabetical.
- In `main.tofu`, put modules before resources; sort blocks by type and then name. Keep blocks using the same module source contiguous.
- In `data.tofu`, sort blocks by type and then name.
- Keep block arguments alphabetical, with module `source` first, followed by a blank line and alphabetized meta-arguments, then other arguments.
- Put resource meta-arguments first and alphabetize them.
- Use two-space indentation and run `tofu fmt`.

Every variable must have a description and type. Mark secrets `sensitive = true` and validate constrained values. Every output must have a description and a name matching the exposed attribute.

Use `prevent_destroy = true` for critical resources in root configurations. Reusable child modules must not declare `prevent_destroy`; root configurations control destruction. Use `ignore_changes` only for externally managed fields. Prefer `enabled` over `count` for conditional resource creation when supported by the required OpenTofu version.

Use the configured state backend and encryption. Never commit credentials or state, or introduce an unencrypted state fallback.

## Environments and Automation

Factory uses **Sandbox**, **Non-Production**, and **Production** environments. Keep environment-specific configuration explicit and consistent across the three.

Pin GitHub Actions to full 40-character commit SHAs with inline version comments. Do not add deployment behavior that bypasses the repository's configured execution and promotion flow.

## Validation and Pre-commit

Use focused checks while iterating. Inspect OpenTofu test providers before running a suite; do not assume `tofu test` is mocked or safe to run against real infrastructure.

For suites requiring a workspace or CLI arguments, use a `.tofu-test.yaml` in the tested directory. Keep variable-file paths relative to that directory and reuse environment and team tfvars rather than duplicating their values or changing deployment defaults to make tests pass.

The Copilot session-start hook in `.github/hooks/pre-commit.json` runs `pre-commit autoupdate --freeze` from the repository root when a session starts or resumes. It may modify `.pre-commit-config.yaml`; do not repeat the update manually if the hook succeeded. If the hook did not run or failed, run the update before the first full pre-commit run.

Run `pre-commit run -a` from the repository root before committing. Hooks may fix files automatically and report a failed run because files changed. Review those changes, address any remaining failures, and rerun until all hooks pass. Preserve unrelated work and include reviewed hook revision updates and automatic fixes with the task's commit.

Do not disable hooks or weaken assertions to get a passing run. Any necessary scanner skip must identify the check and give a verified reason; do not invent a justification.

## Documentation and Git

Documentation is not required for every code change. Update only the specific user-facing or operational guidance made inaccurate by a change, or when the user asks for documentation.

Follow Markdown lint rules when editing Markdown. Keep changes focused and preserve unrelated work.

Use GitHub Flow: work on a descriptive branch, open a pull request, and squash-merge after approval. Use sentence-case commit messages and PR titles; do not use Conventional Commit prefixes.
