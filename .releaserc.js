import { readFileSync, writeFileSync } from 'fs';
import { resolve } from 'path';

/**
 * Custom plugin to update version in plugin.json and marketplace.json.
 *
 * Manages the single root-level plugin.json directly.
 */
function updatePluginJsons() {
  return {
    async verifyConditions(_pluginContext, { lastRelease }) {
      if (!lastRelease || !lastRelease.version) {
        console.log('First release - skipping version verification');
        return;
      }

      const lastVersion = lastRelease.version;
      const pluginJsonPath = resolve(process.cwd(), '.claude-plugin/plugin.json');
      const pluginJson = JSON.parse(readFileSync(pluginJsonPath, 'utf8'));

      if (pluginJson.version !== lastVersion) {
        console.warn(`\n⚠️  plugin.json version mismatch: ${pluginJson.version} (expected ${lastVersion})`);
        console.warn('This will be synchronized to the next version.\n');
      }

      const marketplacePath = resolve(process.cwd(), '.claude-plugin/marketplace.json');
      const marketplace = JSON.parse(readFileSync(marketplacePath, 'utf8'));
      const marketplaceMismatches = marketplace.plugins.filter((p) => p.version !== lastVersion);

      if (marketplaceMismatches.length > 0) {
        console.warn('⚠️  Marketplace version mismatches:');
        marketplaceMismatches.forEach((p) => {
          console.warn(`  ${p.name}: ${p.version} (expected ${lastVersion})`);
        });
        console.warn('These will be synchronized to the next version.\n');
      }
    },

    async prepare(_pluginContext, { nextRelease: { version } }) {
      const pluginJsonPath = resolve(process.cwd(), '.claude-plugin/plugin.json');
      const pluginJson = JSON.parse(readFileSync(pluginJsonPath, 'utf8'));
      pluginJson.version = version;
      writeFileSync(pluginJsonPath, JSON.stringify(pluginJson, null, 2) + '\n');

      const marketplacePath = resolve(process.cwd(), '.claude-plugin/marketplace.json');
      const marketplace = JSON.parse(readFileSync(marketplacePath, 'utf8'));
      marketplace.plugins = marketplace.plugins.map((plugin) => ({ ...plugin, version }));
      writeFileSync(marketplacePath, JSON.stringify(marketplace, null, 2) + '\n');
    },
  };
}

const plugins = [
  [
    '@semantic-release/commit-analyzer',
    {
      preset: 'angular',
      releaseRules: [
        { type: 'refactor', release: 'patch' },
        { type: 'chore', release: 'patch' },
        { type: 'docs', release: 'patch' },
        { type: 'style', release: 'patch' },
        { type: 'test', release: 'patch' },
        { type: 'build', release: 'patch' },
        { type: 'ci', release: 'patch' },
        { type: 'perf', release: 'patch' },
      ],
    },
  ],
  '@semantic-release/release-notes-generator',
  updatePluginJsons(),
  [
    '@semantic-release/git',
    {
      assets: [
        '.claude-plugin/plugin.json',
        '.claude-plugin/marketplace.json',
      ],
      message: 'chore(release): ${nextRelease.version}\n\n${nextRelease.notes}',
    },
  ],
  [
    '@semantic-release/github',
    {
      successComment: false,
      failComment: false,
    },
  ],
];

export default {
  branches: ['main'],
  plugins,
};
