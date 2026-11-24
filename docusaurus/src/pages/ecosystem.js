import Layout from '@theme/Layout';
import styles from './ecosystem.module.css';

const categories = [
  {
    id: 'cncf',
    label: 'CNCF Projects',
    description: 'Projects from the Cloud Native Computing Foundation.',
    tools: [
      {
        name: 'Kubernetes',
        logo: '/img/kubernetes.svg',
        description:
          'Runs the Local Floor, its controllers, and the integration workloads.',
        href: 'https://kubernetes.io',
        cncf: true,
      },
      {
        name: 'Istio',
        logo: '/img/istio.png',
        description:
          'Service mesh, gateway, and ambient mTLS configuration.',
        href: 'https://istio.io',
        cncf: true,
      },
      {
        name: 'cert-manager',
        logo: '/img/cert-manager.png',
        description:
          'Kubernetes certificate management and Istio CSR integration.',
        href: 'https://cert-manager.io',
        cncf: true,
      },
      {
        name: 'OPA Gatekeeper',
        logo: '/img/opa.png',
        description:
          'Kubernetes admission policy modules and configuration.',
        href: 'https://open-policy-agent.github.io/gatekeeper',
        cncf: true,
      },
      {
        name: 'Helm',
        logo: '/img/helm.svg',
        description:
          'Kubernetes package management for platform components and local integration tests.',
        href: 'https://helm.sh',
        cncf: true,
      },
      {
        name: 'Flux',
        logo: '/img/flux.svg',
        description:
          'Reconciles Factory configuration in the Local Floor.',
        href: 'https://fluxcd.io',
        cncf: true,
      },
      {
        name: 'Agent Substrate',
        logo: '/img/agent-substrate.png',
        logoAlt: 'Agent Substrate Yolo logo by Nan Hockin (CC BY 4.0)',
        description:
          'Kubernetes modules and local integration fixtures for agent workloads.',
        href: 'https://github.com/agent-substrate/substrate',
        cncf: true,
      },
      {
        name: 'kagent',
        logo: '/img/kagent-logo-mark.png',
        description:
          'Kubernetes modules and local integration fixtures for agent workloads.',
        href: 'https://kagent.dev',
        cncf: true,
      },
    ],
  },
  {
    id: 'linux-foundation',
    label: 'Linux Foundation Projects',
    description: 'Projects from the Linux Foundation.',
    tools: [
      {
        name: 'agentgateway',
        logo: '/img/agentgateway.svg',
        description:
          'Gateway and policy configuration for agent traffic.',
        href: 'https://agentgateway.dev',
        lf: true,
      },
      {
        name: 'OpenTofu',
        logo: '/img/opentofu.png',
        description:
          'Infrastructure as code across cloud resources and Kubernetes configuration.',
        href: 'https://opentofu.org',
        lf: true,
      },
      {
        name: 'OpenBao',
        logo: '/img/openbao-color.svg',
        logoAlt: 'OpenBao logo by OpenBao (CC BY 4.0)',
        description:
          'Secrets management and identity integration in local tests.',
        href: 'https://openbao.org',
        lf: true,
      },
    ],
  },
  {
    id: 'other-open-source',
    label: 'Other Open Source',
    description: 'Other open-source projects used by Factory.',
    tools: [
      {
        name: 'authentik',
        logo: '/img/authentik.svg',
        description:
          'Identity provider and browser authentication for local gateway tests.',
        href: 'https://goauthentik.io',
      },
      {
        name: 'pre-commit',
        logo: '/img/pre-commit.svg',
        description:
          'Runs repository formatting and validation hooks.',
        href: 'https://pre-commit.com',
      },
      {
        name: 'Docusaurus',
        logo: '/img/docusaurus.svg',
        description: 'Builds the Factory documentation site.',
        href: 'https://docusaurus.io',
      },
    ],
  },
  {
    id: 'vendors',
    label: 'Vendor Products & Services',
    description: 'Vendor products and services used by Factory.',
    tools: [
      {
        name: 'Google Cloud Platform',
        logo: '/img/google-cloud.svg',
        description:
          'Cloud resources for projects, networking, DNS, storage, encryption, and billing.',
        href: 'https://cloud.google.com',
      },
      {
        name: 'Docker Desktop',
        logo: '/img/docker.svg',
        description:
          'Docker Desktop hosts the local Kubernetes environment for Floor and integration tests.',
        href: 'https://www.docker.com',
      },
      {
        name: 'GitHub',
        logo: '/img/github-mark.svg',
        description:
          'Hosts the Factory source repository, pull requests, and project documentation.',
        href: 'https://github.com/osinfra-io/factory',
      },
    ],
  },
];

function ToolCard({name, logo, logoAlt, description, href, cncf, lf}) {
  const CardElement = href ? 'a' : 'article';

  return (
    <CardElement
      {...(href && {
        href,
        target: '_blank',
        rel: 'noopener noreferrer',
      })}
      className={styles.card}
    >
      <div className={styles.logoWrapper}>
        {logo ? (
          <img
            src={logo}
            alt={logoAlt || name}
            className={styles.logo}
          />
        ) : (
          <span className={styles.logoFallback} aria-hidden="true">
            {name[0]}
          </span>
        )}
      </div>
      <div className={styles.cardBody}>
        <h3 className={styles.cardTitle}>{name}</h3>
        <p className={styles.cardDescription}>{description}</p>
        {cncf && (
          <img
            src="/img/cncf.png"
            alt="CNCF"
            className={styles.cncfBadge}
            title="CNCF Project"
          />
        )}
        {lf && (
          <img
            src="/img/linux-foundation.svg"
            alt="Linux Foundation"
            className={styles.lfBadge}
            title="Linux Foundation Project"
          />
        )}
      </div>
    </CardElement>
  );
}

export default function Ecosystem() {
  return (
    <Layout
      title="Ecosystem"
      description="Technologies used by the Factory codebase."
    >
      <main className={styles.page}>
        <header className={styles.header}>
          <h1 className={styles.title}>Ecosystem</h1>
          <p className={styles.subtitle}>
            The tools represented in the current Factory codebase, grouped by
            vendor or foundation affiliation.
          </p>
        </header>

        <div className={styles.content}>
          {categories.map((category) => (
            <section
              key={category.id}
              className={styles.section}
              aria-labelledby={category.id}
            >
              <h2 id={category.id} className={styles.categoryLabel}>
                {category.label}
              </h2>
              <p className={styles.categoryDescription}>
                {category.description}
              </p>
              <div className={styles.grid}>
                {category.tools.map((tool) => (
                  <ToolCard key={tool.name} {...tool} />
                ))}
              </div>
            </section>
          ))}
        </div>
      </main>
    </Layout>
  );
}
