# Factory documentation site

The Factory documentation site is built with Docusaurus and configured for
`https://docs.osinfra.io`. Its pages describe the architecture and workflows
implemented in this repository.

## Local development

Use Node.js 20 or newer and Yarn Classic. From the repository root:

```bash
cd docusaurus
yarn install --frozen-lockfile
yarn start
```

The local site is available at `http://localhost:3000`. To build the site:

```bash
yarn build
```

## Structure

| Path | Purpose |
| --- | --- |
| `docusaurus/docs/{explore,run,use}.md` | Entry points for each audience |
| `docusaurus/docs/architecture/` | Architecture overview, layers, and environment lifecycle |
| `docusaurus/docs/local-development.md` | Docusaurus and local integration development |
| `docusaurus/src/` | Site pages, React components, and CSS |
| `docusaurus/static/` | Static assets and custom-domain configuration |
| `docusaurus/docusaurus.config.js` | Site configuration |
| `docusaurus/sidebars.js` | Documentation navigation |

Keep the docs aligned with the current Factory code. Mark future work as target
architecture rather than describing it as deployed functionality. Run
`yarn build` from `docusaurus/` before publishing changes.
