import Link from '@docusaurus/Link';
import Layout from '@theme/Layout';
import Heading from '@theme/Heading';
import Card from '@site/src/components/Card';
import CardGrid from '@site/src/components/CardGrid';
import CardIcon from '@site/src/components/CardIcon';

import styles from './index.module.css';

const features = [
  {
    title: 'Three clear infrastructure layers',
    description:
      'Foundation establishes folders and metadata, Assembly composes cloud infrastructure, and Runtime creates GKE clusters from Assembly outputs.',
    icon: 'buildingFactory',
  },
  {
    title: 'Reviewed infrastructure plans',
    description:
      'Review OpenTofu plans and explicitly approve the exact plan before cloud changes are applied.',
    icon: 'shieldLock',
  },
  {
    title: 'Local end-to-end testing',
    description:
      'An opt-in Docker Desktop stack verifies cross-component behavior locally; it does not validate GCP networking or workload identity.',
    icon: 'flask',
  },
];

const cards = [
  {
    icon: 'buildingBank',
    title: 'Explore',
    note: 'Discover the project, its open-source ecosystem, and how to try it.',
    link: '/explore',
    linkText: 'Explore →',
  },
  {
    icon: 'world',
    title: 'Run',
    note: 'Build, maintain, and operate Factory for your organization.',
    link: '/run',
    linkText: 'Run →',
  },
  {
    icon: 'tools',
    title: 'Use',
    note: 'Explore how development teams can use Factory infrastructure.',
    link: '/use',
    linkText: 'Use →',
  },
];

const whatYouGet = [
  {
    icon: 'buildingBank',
    title: 'Foundation',
    note: 'Configured team folders and environment metadata for downstream layers.',
  },
  {
    icon: 'world',
    title: 'Assembly',
    note: 'Cloud projects, shared networking, DNS, registry, and regional resources.',
  },
  {
    icon: 'wheel',
    title: 'Runtime',
    note: 'GKE clusters for configured team locations; cluster services and routes are separate work.',
  },
  {
    icon: 'tools',
    title: 'Floor',
    note: 'Local Flux and tofu-controller orchestration for reviewed OpenTofu plans.',
  },
];

const techLogoGroups = [
  {
    label: 'CNCF',
    logos: [
      {src: '/img/kubernetes.svg', alt: 'Kubernetes'},
      {src: '/img/istio.png', alt: 'Istio'},
      {src: '/img/cert-manager.png', alt: 'cert-manager'},
      {src: '/img/opa.png', alt: 'OPA Gatekeeper'},
      {src: '/img/helm.svg', alt: 'Helm'},
      {src: '/img/flux.svg', alt: 'Flux'},
      {src: '/img/agent-substrate.png', alt: 'Agent Substrate'},
      {src: '/img/kagent-logo-mark.png', alt: 'kagent'},
    ],
  },
  {
    label: 'Linux Foundation',
    logos: [
      {src: '/img/agentgateway.svg', alt: 'agentgateway'},
      {src: '/img/opentofu.png', alt: 'OpenTofu'},
      {src: '/img/openbao-color.svg', alt: 'OpenBao logo by OpenBao (CC BY 4.0)'},
    ],
  },
  {
    label: 'Other open source',
    logos: [
      {src: '/img/authentik.svg', alt: 'authentik'},
      {src: '/img/pre-commit.svg', alt: 'pre-commit'},
      {src: '/img/docusaurus.svg', alt: 'Docusaurus'},
    ],
  },
  {
    label: 'Vendor',
    logos: [
      {src: '/img/google-cloud.svg', alt: 'Google Cloud'},
      {src: '/img/docker.svg', alt: 'Docker Desktop'},
      {src: '/img/github-mark.svg', alt: 'GitHub'},
    ],
  },
];

function WhatYouGet() {
  return (
    <section className={styles.whatYouGet}>
      <div className="container">
        <Heading as="h2" className={styles.whatYouGetHeading}>
          What the codebase provides
        </Heading>
        <p className={styles.whatYouGetSubtitle}>
          Current implementation boundaries, not a promise that every environment
          is deployed.
        </p>
        <div className={styles.whatYouGetGrid}>
          {whatYouGet.map((item) => (
            <div key={item.title} className={styles.whatYouGetItem}>
              <span className={styles.whatYouGetIcon}>
                <CardIcon name={item.icon} />
              </span>
              <div>
                <div className={styles.whatYouGetTitle}>{item.title}</div>
                <div className={styles.whatYouGetNote}>{item.note}</div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

function HomeFooter() {
  return (
    <footer className={styles.homeFooter}>
      <div className={styles.homeFooterInner}>
        <div className={styles.homeFooterBrand}>
          <img
            src="/img/osinfra-logo-full.png"
            alt="osinfra.io"
            className={styles.homeFooterLogo}
          />
        </div>
        <div className={styles.homeFooterLinks}>
          <div className={styles.homeFooterCol}>
            <span className={styles.homeFooterColTitle}>Project</span>
            <a
              href="https://github.com/osinfra-io/factory"
              className={styles.homeFooterLink}
              target="_blank"
              rel="noopener noreferrer"
            >
              GitHub
            </a>
            <a
              href="https://github.com/sponsors/osinfra-io?frequency=one-time"
              className={styles.homeFooterLink}
              target="_blank"
              rel="noopener noreferrer"
            >
              Sponsor
            </a>
          </div>
        </div>
      </div>
    </footer>
  );
}

function TechLogoGroups({decorative = false}) {
  return (
    <div
      className={styles.techStripContent}
      aria-hidden={decorative || undefined}
    >
      {techLogoGroups.map((group) => (
        <div key={group.label} className={styles.techStripGroup}>
          <span className={styles.techStripLabel}>{group.label}</span>
          <div className={styles.techStripLogos}>
            {group.logos.map((logo) => (
              <img
                key={logo.alt}
                src={logo.src}
                alt={decorative ? '' : logo.alt}
                className={styles.techStripLogo}
                title={decorative ? undefined : logo.alt}
              />
            ))}
          </div>
        </div>
      ))}
    </div>
  );
}

function TechStrip() {
  return (
    <div className={styles.techStrip}>
      <Link
        to="/ecosystem"
        className={styles.techStripInner}
        aria-label="Explore the ecosystem"
      >
        <span className={styles.techStripTitle}>Powered by</span>
        <div className={styles.techStripLogosRow}>
          <div className={styles.techStripViewport}>
            <div className={styles.techStripTrack}>
              <TechLogoGroups />
              <TechLogoGroups decorative />
            </div>
          </div>
        </div>
      </Link>
    </div>
  );
}

function Hero() {
  return (
    <header className={styles.hero}>
      <div className={styles.heroInner}>
        <img
          src="/img/osinfra-logo-full.png"
          alt="osinfra.io"
          className={styles.heroLogo}
        />
        <p className={styles.heroTagline}>
          Secure, reliable infrastructure. From request to production.
        </p>
        <p className={styles.heroSubtitle}>
          Organize agents, workflows, and human responsibilities around that
          outcome. Factory is an open-source reference implementation for
          building and running your own infrastructure platform.
        </p>
        <div className={styles.heroActions}>
          <Link to="/explore" className={styles.gettingStartedCta}>
            Explore Factory →
          </Link>
          <Link
            to="/run"
            className={styles.heroSecondaryCta}
          >
            Run Factory
          </Link>
        </div>
      </div>
    </header>
  );
}

function Features() {
  return (
    <section className={styles.features}>
      <div className="container">
        <div className={styles.featureGrid}>
          {features.map((feature) => (
            <div key={feature.title} className={styles.featureItem}>
              <span className={styles.featureIcon}>
                <CardIcon name={feature.icon} size={32} />
              </span>
              <Heading as="h3" className={styles.featureTitle}>
                {feature.title}
              </Heading>
              <p className={styles.featureDescription}>{feature.description}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

function CallToAction() {
  return (
    <section className={styles.cta}>
      <div className="container">
        <Heading as="h2" className={styles.ctaHeading}>
          Find your way through Factory
        </Heading>
        <CardGrid>
          {cards.map((card) => <Card key={card.title} item={card} />)}
        </CardGrid>
      </div>
    </section>
  );
}

export default function Home() {
  return (
    <Layout
      noFooter
      title="Factory"
      description="Architecture and implementation documentation for Factory."
    >
      <Hero />
      <main>
        <CallToAction />
        <Features />
        <WhatYouGet />
        <TechStrip />
      </main>
      <HomeFooter />
    </Layout>
  );
}
