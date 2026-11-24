// @ts-check

// Keep the region markers below unchanged. External documentation automation
// uses them as insertion points for additional pages.

/** @type {import('@docusaurus/plugin-content-docs').SidebarsConfig} */
const sidebars = {
  explore: [
    'explore',
    {type: 'link', label: 'Ecosystem', href: '/ecosystem'},
  ],
  run: [
    'run',
    'architecture/index',
    {
      type: 'category',
      label: 'Architecture',
      items: [
        'architecture/environment-lifecycle',
        'architecture/foundation',
        'architecture/assembly',
        'architecture/runtime',
        'architecture/floor',
        // region: platform-grouping
        // endregion: platform-grouping
        // region: stream-aligned-teams
        // endregion: stream-aligned-teams
        // region: complicated-subsystem-teams
        // endregion: complicated-subsystem-teams
        // region: enabling-teams
        // endregion: enabling-teams
      ],
    },
    'local-development',
  ],
  use: [
    'use',
  ],
};

export default sidebars;
