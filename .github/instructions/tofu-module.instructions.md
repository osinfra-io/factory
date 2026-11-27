---
applyTo: "tofu/modules/**"
---

# OpenTofu Module Instructions

Reusable OpenTofu modules live under `tofu/modules/<domain>/<module>`. Each module and functional submodule is independently addressable and owns its inputs, outputs, data sources, resources, and tests.

## Module Structure

Use the standard module files described in `.github/instructions/factory.instructions.md`. Add `data.tofu` and `moved.tofu` only when needed. A module root with no other `.tofu` file may keep an empty `empty.tofu` when required for `tofu init` or `tofu test`; do not leave other empty or comment-only files.

Use descriptive module, resource, and data-source names. Dependency paths, shared files, computed values, ordering, formatting, and lifecycle rules follow the repository-wide instructions; do not introduce module-specific exceptions.

## Tests and Documentation

Add focused mocked OpenTofu tests in the module's `tests/` directory for behavior introduced or fixed by a change. Run `tofu test` from the module root with any workspace and arguments declared in its `.tofu-test.yaml`. Tests should verify the intended reference baseline without requiring cloud credentials or creating infrastructure. Use `command = plan` unless the behavior under test requires applied values.

Cross-component local Kubernetes checks belong in the repository's `tests/integration/`, not in individual modules. They are optional developer checks; follow `.github/skills/local-integration-testing/SKILL.md` when they apply.

Do not create or update module READMEs routinely. Make only the specific documentation change needed for user-visible or operational guidance, or when the user requests it.
