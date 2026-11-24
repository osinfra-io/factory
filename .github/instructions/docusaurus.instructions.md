---
applyTo: "docusaurus/**"
---

# Docusaurus Documentation Instructions

The Docusaurus site documents the Factory architecture and the implementation
present in this repository. Do not describe legacy repositories, teams,
onboarding agents, or capabilities that are not implemented here. Distinguish
checked-in configuration from approved or applied infrastructure.

## Documentation structure

- `docs/architecture/index.md` is the architecture overview.
- `docs/architecture/environment-lifecycle.md` describes environment rollout,
  DNS gates, and reconciliation handoff.
- `docs/architecture/` contains pages for Foundation, Assembly, Runtime, and
  Floor.
- `docs/local-development.md` describes the documentation site and local
  integration workflow.

Use the existing architecture terms consistently:

- **Foundation** establishes organizational and environment foundations.
- **Assembly** composes cloud infrastructure, projects, and environments.
- **Runtime** provides clusters and workload capabilities.
- **Floor** is the execution and orchestration environment across these layers,
  not another layer.

Keep documentation concise and grounded in source code and tests in this
repository. Label plans and target architecture as such. Do not claim that a
plan was approved, infrastructure was applied, or a service is live unless that
status has been verified.

## Sidebar

Update `sidebars.js` when adding, removing, or moving documentation pages. Keep
the `// region: <section>` and `// endregion: <section>` markers unchanged;
external documentation automation uses these markers as insertion points.

## Markdown and Mermaid

- Put Docusaurus front matter before the page heading.
- Use relative links between documentation pages.
- Mermaid diagrams are enabled in the site.
- Preserve the platform-wide Markdown lint settings. This site also disables
  `MD041` because pages use front matter and `MD046` because MDX admonitions
  use different indentation.

## Validation

From `docusaurus/`, run:

```bash
yarn build
```
