import { readFileSync, writeFileSync, readdirSync, existsSync } from 'fs';
import { resolve } from 'path';

/**
 * Dynamically discover all plugins from the plugins directory.
 * A plugin is identified by the presence of .claude-plugin/plugin.json.
 */
function discoverPlugins() {
  const pluginsDir = resolve(process.cwd(), 'plugins');
  const plugins = [];

  for (const entry of readdirSync(pluginsDir, { withFileTypes: true })) {
    if (entry.isDirectory()) {
      const pluginJsonPath = resolve(pluginsDir, entry.name, '.claude-plugin/plugin.json');
      if (existsSync(pluginJsonPath)) {
        plugins.push(entry.name);
      }
    }
  }

  return plugins;
}

/**
 * Custom plugin to update version in plugin.json files.
 *
 * Ensures all plugin.json versions are synchronized with marketplace.json
 * during the release process. Each plugin has its own plugin.json that needs
 * to be updated to the same version.
 */
function updatePluginJsons() {
  return {
    async verifyConditions(_pluginContext, { lastRelease }) {
      // First release - skip verification
      if (!lastRelease || !lastRelease.version) {
        console.log('First release - skipping version verification');
        return;
      }

      const plugins = discoverPlugins();
      const mismatches = [];
      const lastVersion = lastRelease.version;

      // Check each plugin.json
      for (const plugin of plugins) {
        const pluginJsonPath = resolve(
          process.cwd(),
          `plugins/${plugin}/.claude-plugin/plugin.json`
        );
        const pluginJson = JSON.parse(readFileSync(pluginJsonPath, 'utf8'));

        if (pluginJson.version !== lastVersion) {
          mismatches.push({
            plugin,
            current: pluginJson.version,
            expected: lastVersion,
          });
        }
      }

      // Check marketplace.json
      const marketplacePath = resolve(process.cwd(), '.claude-plugin/marketplace.json');
      const marketplace = JSON.parse(readFileSync(marketplacePath, 'utf8'));

      const marketplaceMismatches = marketplace.plugins.filter(
        (p) => p.version !== lastVersion
      );

      // Log warnings but don't fail the release
      if (mismatches.length > 0) {
        console.warn('\n⚠️  Plugin version mismatches detected:');
        mismatches.forEach(({ plugin, current, expected }) => {
          console.warn(`  ${plugin}: ${current} (expected ${expected})`);
        });
        console.warn('These will be synchronized to the next version.\n');
      }

      if (marketplaceMismatches.length > 0) {
        console.warn('⚠️  Marketplace version mismatches:');
        marketplaceMismatches.forEach((p) => {
          console.warn(`  ${p.name}: ${p.version} (expected ${lastVersion})`);
        });
        console.warn('These will be synchronized to the next version.\n');
      }
    },

    async prepare(_pluginContext, { nextRelease: { version } }) {
      const plugins = discoverPlugins();

      for (const plugin of plugins) {
        const pluginJsonPath = resolve(
          process.cwd(),
          `plugins/${plugin}/.claude-plugin/plugin.json`
        );
        const pluginJson = JSON.parse(readFileSync(pluginJsonPath, 'utf8'));
        pluginJson.version = version;
        writeFileSync(pluginJsonPath, JSON.stringify(pluginJson, null, 2) + '\n');
      }

      // Update marketplace.json
      const marketplacePath = resolve(process.cwd(), '.claude-plugin/marketplace.json');
      const marketplace = JSON.parse(readFileSync(marketplacePath, 'utf8'));

      // Update all plugin versions in marketplace.json
      marketplace.plugins = marketplace.plugins.map((plugin) => ({
        ...plugin,
        version,
      }));

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
        'plugins/*/.claude-plugin/plugin.json',
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
