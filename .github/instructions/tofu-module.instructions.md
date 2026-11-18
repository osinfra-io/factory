---
applyTo: "tofu/modules/**"
---

# OpenTofu Module Instructions

Reusable OpenTofu modules live under `tofu/modules/<domain>/<module>`. Each module and functional submodule is independently addressable and owns its inputs, outputs, data sources, resources, and tests.

## Module Structure

Use the standard module files described in `.github/instructions/factory.instructions.md`. Add `data.tofu` and `moved.tofu` only when needed. A module root with no other `.tofu` file may keep an empty `empty.tofu` when required for `tofu init` or `tofu test`; do not leave other empty or comment-only files.

Use local relative paths for dependencies between modules in this repository. Keep identical shared files in the nearest `shared/` directory and symlink them into each consumer rather than duplicating content.

Keep conditional logic, string transformations, and computed values in `locals.tofu`. Use descriptive module, resource, and data-source names. Keep block ordering, arguments, and formatting consistent with the factory-wide OpenTofu conventions.

Child modules must not declare `prevent_destroy`; callers control the lifecycle of deployed infrastructure.

## Tests and Documentation

Add focused mocked OpenTofu tests in the module's `tests/` directory for behavior introduced or fixed by a change. Run `tofu test` from the module root. Tests should verify the intended reference baseline without requiring cloud credentials or creating infrastructure.

Cross-component local Kubernetes checks belong in the repository's `tests/integration/`, not in individual modules. They are optional developer checks; follow `.github/skills/local-integration-testing/SKILL.md` when they apply.

Do not create or update module READMEs routinely. Make only the specific documentation change needed for user-visible or operational guidance, or when the user requests it.
