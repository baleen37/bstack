#!/usr/bin/env node

import fs from 'fs';
import path from 'path';
import { createRequire } from 'module';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const CATEGORIES = [
  'Tool Coverage',
  'Context Efficiency',
  'Quality Gates',
  'Memory Persistence',
  'Eval Coverage',
  'Security Guardrails',
  'Cost Efficiency',
];

function normalizeScope(scope) {
  const value = (scope || 'repo').toLowerCase();
  if (!['repo', 'hooks', 'skills', 'commands', 'agents'].includes(value)) {
    throw new Error(`Invalid scope: ${scope}`);
  }
  return value;
}

function parseArgs(argv) {
  const args = argv.slice(2);
  const parsed = {
    scope: 'repo',
    format: 'text',
    help: false,
    root: path.resolve(process.env.AUDIT_ROOT || process.cwd()),
  };

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];

    if (arg === '--help' || arg === '-h') {
      parsed.help = true;
      continue;
    }

    if (arg === '--format') {
      parsed.format = (args[index + 1] || '').toLowerCase();
      index += 1;
      continue;
    }

    if (arg === '--scope') {
      parsed.scope = normalizeScope(args[index + 1]);
      index += 1;
      continue;
    }

    if (arg === '--root') {
      parsed.root = path.resolve(args[index + 1] || process.cwd());
      index += 1;
      continue;
    }

    if (arg.startsWith('--format=')) {
      parsed.format = arg.split('=')[1].toLowerCase();
      continue;
    }

    if (arg.startsWith('--scope=')) {
      parsed.scope = normalizeScope(arg.split('=')[1]);
      continue;
    }

    if (arg.startsWith('--root=')) {
      parsed.root = path.resolve(arg.slice('--root='.length));
      continue;
    }

    if (arg.startsWith('-')) {
      throw new Error(`Unknown argument: ${arg}`);
    }

    parsed.scope = normalizeScope(arg);
  }

  if (!['text', 'json'].includes(parsed.format)) {
    throw new Error(`Invalid format: ${parsed.format}. Use text or json.`);
  }

  return parsed;
}

function fileExists(rootDir, relativePath) {
  return fs.existsSync(path.join(rootDir, relativePath));
}

function readText(rootDir, relativePath) {
  return fs.readFileSync(path.join(rootDir, relativePath), 'utf8');
}

function countFiles(rootDir, relativeDir, extension) {
  const dirPath = path.join(rootDir, relativeDir);
  if (!fs.existsSync(dirPath)) {
    return 0;
  }

  const stack = [dirPath];
  let count = 0;

  while (stack.length > 0) {
    const current = stack.pop();
    const entries = fs.readdirSync(current, { withFileTypes: true });

    for (const entry of entries) {
      const nextPath = path.join(current, entry.name);
      if (entry.isDirectory()) {
        stack.push(nextPath);
      } else if (!extension || entry.name.endsWith(extension)) {
        count += 1;
      }
    }
  }

  return count;
}

function safeRead(rootDir, relativePath) {
  try {
    return readText(rootDir, relativePath);
  } catch (_error) {
    return '';
  }
}

function safeParseJson(text) {
  if (!text || !text.trim()) {
    return null;
  }

  try {
    return JSON.parse(text);
  } catch (_error) {
    return null;
  }
}

function hasFileWithExtension(rootDir, relativeDir, extensions) {
  const dirPath = path.join(rootDir, relativeDir);
  if (!fs.existsSync(dirPath)) {
    return false;
  }

  const allowed = Array.isArray(extensions) ? extensions : [extensions];
  const stack = [dirPath];

  while (stack.length > 0) {
    const current = stack.pop();
    const entries = fs.readdirSync(current, { withFileTypes: true });

    for (const entry of entries) {
      const nextPath = path.join(current, entry.name);
      if (entry.isDirectory()) {
        stack.push(nextPath);
        continue;
      }

      if (allowed.some((extension) => entry.name.endsWith(extension))) {
        return true;
      }
    }
  }

  return false;
}

function detectTargetMode(rootDir) {
  const packageJson = safeParseJson(safeRead(rootDir, 'package.json'));
  if (packageJson?.name === 'everything-claude-code' || packageJson?.name === 'me') {
    return 'repo';
  }

  if (
    fileExists(rootDir, 'scripts/harness-audit.js') &&
    fileExists(rootDir, 'plugins/me/.claude-plugin/plugin.json') &&
    fileExists(rootDir, 'plugins/me/hooks') &&
    fileExists(rootDir, 'plugins/me/skills')
  ) {
    return 'repo';
  }

  return 'consumer';
}

function findPluginInstall(rootDir) {
  const homeDir = process.env.HOME || '';
  const pluginDirs = [
    'ecc',
    'ecc@ecc',
    'everything-claude-code',
    'everything-claude-code@everything-claude-code',
  ];
  const candidateRoots = [
    path.join(rootDir, '.claude', 'plugins'),
    homeDir && path.join(homeDir, '.claude', 'plugins'),
  ].filter(Boolean);
  const candidates = candidateRoots.flatMap((pluginsDir) =>
    pluginDirs.flatMap((pluginDir) => [
      path.join(pluginsDir, pluginDir, '.claude-plugin', 'plugin.json'),
      path.join(pluginsDir, pluginDir, 'plugin.json'),
    ])
  );

  return candidates.find(candidate => fs.existsSync(candidate)) || null;
}

function getRepoChecks(rootDir) {
  const packageJson = JSON.parse(readText(rootDir, 'package.json'));
  const gitignore = safeRead(rootDir, '.gitignore');

  return [
    // Tool Coverage
    {
      id: 'tool-hooks-dir',
      category: 'Tool Coverage',
      points: 2,
      scopes: ['repo', 'hooks'],
      path: 'plugins/me/hooks/',
      description: 'plugins/me/hooks/ directory exists',
      pass: fileExists(rootDir, 'plugins/me/hooks'),
      fix: 'Create plugins/me/hooks/ and add hook scripts.',
    },
    {
      id: 'tool-plugin-json',
      category: 'Tool Coverage',
      points: 2,
      scopes: ['repo'],
      path: 'plugins/me/.claude-plugin/plugin.json',
      description: 'plugins/me/.claude-plugin/plugin.json exists',
      pass: fileExists(rootDir, 'plugins/me/.claude-plugin/plugin.json'),
      fix: 'Add plugin manifest at plugins/me/.claude-plugin/plugin.json.',
    },
    {
      id: 'tool-skill-count',
      category: 'Tool Coverage',
      points: 3,
      scopes: ['repo', 'skills'],
      path: 'plugins/',
      description: 'At least 10 SKILL.md files across plugins/',
      pass: countFiles(rootDir, 'plugins', 'SKILL.md') >= 10,
      fix: 'Add missing skill directories with SKILL.md definitions under plugins/.',
    },
    {
      id: 'tool-plugin-count',
      category: 'Tool Coverage',
      points: 3,
      scopes: ['repo'],
      path: 'plugins/',
      description: 'At least 3 plugin directories in plugins/',
      pass: (() => {
        const pluginsDir = path.join(rootDir, 'plugins');
        if (!fs.existsSync(pluginsDir)) return false;
        return fs.readdirSync(pluginsDir, { withFileTypes: true }).filter(e => e.isDirectory()).length >= 3;
      })(),
      fix: 'Ensure at least 3 plugin directories exist under plugins/.',
    },
    // Context Efficiency
    {
      id: 'context-claude-md',
      category: 'Context Efficiency',
      points: 4,
      scopes: ['repo'],
      path: 'CLAUDE.md',
      description: 'CLAUDE.md exists at project root',
      pass: fileExists(rootDir, 'CLAUDE.md'),
      fix: 'Add CLAUDE.md with project guidance for AI agents.',
    },
    {
      id: 'context-agents-md',
      category: 'Context Efficiency',
      points: 3,
      scopes: ['repo', 'agents'],
      path: '**/AGENTS.md',
      description: 'At least one AGENTS.md file exists (recursively)',
      pass: countFiles(rootDir, '.', 'AGENTS.md') >= 1,
      fix: 'Add at least one AGENTS.md to provide agent-specific context.',
    },
    {
      id: 'context-readme',
      category: 'Context Efficiency',
      points: 3,
      scopes: ['repo'],
      path: 'README.md',
      description: 'README.md exists',
      pass: fileExists(rootDir, 'README.md'),
      fix: 'Add README.md with project overview.',
    },
    // Quality Gates
    {
      id: 'quality-test-runner',
      category: 'Quality Gates',
      points: 3,
      scopes: ['repo'],
      path: 'tests/run-all-tests.sh',
      description: 'Central test runner exists',
      pass: fileExists(rootDir, 'tests/run-all-tests.sh'),
      fix: 'Add tests/run-all-tests.sh to enforce complete suite execution.',
    },
    {
      id: 'quality-test-count',
      category: 'Quality Gates',
      points: 3,
      scopes: ['repo'],
      path: 'tests/',
      description: 'At least 5 .bats test files in tests/',
      pass: countFiles(rootDir, 'tests', '.bats') >= 5,
      fix: 'Add BATS test files in tests/ to improve coverage.',
    },
    {
      id: 'quality-pre-commit',
      category: 'Quality Gates',
      points: 2,
      scopes: ['repo'],
      path: '.pre-commit-config.yaml',
      description: '.pre-commit-config.yaml exists',
      pass: fileExists(rootDir, '.pre-commit-config.yaml'),
      fix: 'Add .pre-commit-config.yaml to enforce pre-commit hooks.',
    },
    {
      id: 'quality-ci',
      category: 'Quality Gates',
      points: 2,
      scopes: ['repo'],
      path: '.github/workflows/',
      description: '.github/workflows/ has yml files',
      pass: hasFileWithExtension(rootDir, '.github/workflows', ['.yml', '.yaml']),
      fix: 'Add CI workflow files under .github/workflows/.',
    },
    // Memory Persistence
    {
      id: 'memory-claude-dir',
      category: 'Memory Persistence',
      points: 5,
      scopes: ['repo'],
      path: '.claude/',
      description: '.claude/ directory exists',
      pass: fileExists(rootDir, '.claude'),
      fix: 'Create .claude/ directory for Claude Code session data.',
    },
    {
      id: 'memory-docs',
      category: 'Memory Persistence',
      points: 5,
      scopes: ['repo'],
      path: 'docs/',
      description: 'docs/ directory exists',
      pass: fileExists(rootDir, 'docs'),
      fix: 'Add docs/ directory for development and testing documentation.',
    },
    // Eval Coverage
    {
      id: 'eval-skill',
      category: 'Eval Coverage',
      points: 5,
      scopes: ['repo', 'skills'],
      path: 'plugins/me/skills/eval-harness/SKILL.md',
      description: 'plugins/me/skills/eval-harness/SKILL.md exists',
      pass: fileExists(rootDir, 'plugins/me/skills/eval-harness/SKILL.md'),
      fix: 'Add plugins/me/skills/eval-harness/SKILL.md for pass/fail regression evaluation.',
    },
    {
      id: 'eval-tests',
      category: 'Eval Coverage',
      points: 5,
      scopes: ['repo'],
      path: 'tests/skills/',
      description: 'At least 3 test files in tests/skills/',
      pass: countFiles(rootDir, 'tests/skills', null) >= 3,
      fix: 'Add at least 3 test files under tests/skills/.',
    },
    // Security Guardrails
    {
      id: 'security-gitignore',
      category: 'Security Guardrails',
      points: 3,
      scopes: ['repo'],
      path: '.gitignore',
      description: '.gitignore includes .env',
      pass: gitignore.includes('.env'),
      fix: 'Add .env patterns to .gitignore to prevent secret leaks.',
    },
    {
      id: 'security-husky',
      category: 'Security Guardrails',
      points: 3,
      scopes: ['repo'],
      path: '.husky/',
      description: '.husky/ directory exists (git hooks protection)',
      pass: fileExists(rootDir, '.husky'),
      fix: 'Add .husky/ directory for git hooks protection via husky.',
    },
    {
      id: 'security-commitlint',
      category: 'Security Guardrails',
      points: 2,
      scopes: ['repo'],
      path: '.commitlintrc.js',
      description: '.commitlintrc.js or .commitlintrc.json exists',
      pass: fileExists(rootDir, '.commitlintrc.js') || fileExists(rootDir, '.commitlintrc.json'),
      fix: 'Add .commitlintrc.js to enforce Conventional Commits format.',
    },
    {
      id: 'security-pre-commit-hooks',
      category: 'Security Guardrails',
      points: 2,
      scopes: ['repo'],
      path: '.pre-commit-config.yaml',
      description: '.pre-commit-config.yaml exists',
      pass: fileExists(rootDir, '.pre-commit-config.yaml'),
      fix: 'Add .pre-commit-config.yaml to run security checks on commit.',
    },
    // Cost Efficiency
    {
      id: 'cost-semantic-release',
      category: 'Cost Efficiency',
      points: 4,
      scopes: ['repo'],
      path: '.releaserc.js',
      description: '.releaserc.js exists',
      pass: fileExists(rootDir, '.releaserc.js'),
      fix: 'Add .releaserc.js for automated semantic versioning.',
    },
    {
      id: 'cost-flake',
      category: 'Cost Efficiency',
      points: 3,
      scopes: ['repo'],
      path: 'flake.nix',
      description: 'flake.nix exists (reproducible env)',
      pass: fileExists(rootDir, 'flake.nix'),
      fix: 'Add flake.nix for a reproducible Nix development environment.',
    },
    {
      id: 'cost-package-scripts',
      category: 'Cost Efficiency',
      points: 3,
      scopes: ['repo'],
      path: 'package.json',
      description: 'package.json has test script',
      pass: typeof packageJson.scripts?.test === 'string',
      fix: 'Add a test script to package.json for automated test execution.',
    },
  ];
}

function getConsumerChecks(rootDir) {
  const packageJson = safeParseJson(safeRead(rootDir, 'package.json'));
  const gitignore = safeRead(rootDir, '.gitignore');
  const projectHooks = safeRead(rootDir, '.claude/settings.json');
  const pluginInstall = findPluginInstall(rootDir);

  return [
    {
      id: 'consumer-plugin-install',
      category: 'Tool Coverage',
      points: 4,
      scopes: ['repo'],
      path: '~/.claude/plugins/ecc/ (legacy everything-claude-code paths also supported)',
      description: 'Everything Claude Code is installed for the active user or project',
      pass: Boolean(pluginInstall),
      fix: 'Install the ECC plugin for this user or project before auditing project-specific harness quality.',
    },
    {
      id: 'consumer-project-overrides',
      category: 'Tool Coverage',
      points: 3,
      scopes: ['repo', 'hooks', 'skills', 'commands', 'agents'],
      path: '.claude/',
      description: 'Project-specific harness overrides exist under .claude/',
      pass: countFiles(rootDir, '.claude/agents', '.md') > 0 ||
        countFiles(rootDir, '.claude/skills', 'SKILL.md') > 0 ||
        countFiles(rootDir, '.claude/commands', '.md') > 0 ||
        fileExists(rootDir, '.claude/settings.json') ||
        fileExists(rootDir, '.claude/hooks.json'),
      fix: 'Add project-local .claude hooks, commands, skills, or settings that tailor ECC to this repo.',
    },
    {
      id: 'consumer-instructions',
      category: 'Context Efficiency',
      points: 3,
      scopes: ['repo'],
      path: 'AGENTS.md',
      description: 'The project has explicit agent or instruction context',
      pass: fileExists(rootDir, 'AGENTS.md') || fileExists(rootDir, 'CLAUDE.md') || fileExists(rootDir, '.claude/CLAUDE.md'),
      fix: 'Add AGENTS.md or CLAUDE.md so the harness has project-specific instructions.',
    },
    {
      id: 'consumer-project-config',
      category: 'Context Efficiency',
      points: 2,
      scopes: ['repo', 'hooks'],
      path: '.mcp.json',
      description: 'The project declares local MCP or Claude settings',
      pass: fileExists(rootDir, '.mcp.json') || fileExists(rootDir, '.claude/settings.json') || fileExists(rootDir, '.claude/settings.local.json'),
      fix: 'Add .mcp.json or .claude/settings.json so project-local tool configuration is explicit.',
    },
    {
      id: 'consumer-test-suite',
      category: 'Quality Gates',
      points: 4,
      scopes: ['repo'],
      path: 'tests/',
      description: 'The project has an automated test entrypoint',
      pass: typeof packageJson?.scripts?.test === 'string' || countFiles(rootDir, 'tests', '.test.js') > 0 || hasFileWithExtension(rootDir, '.', ['.spec.js', '.spec.ts', '.test.ts']),
      fix: 'Add a test script or checked-in tests so harness recommendations can be verified automatically.',
    },
    {
      id: 'consumer-ci-workflow',
      category: 'Quality Gates',
      points: 3,
      scopes: ['repo'],
      path: '.github/workflows/',
      description: 'The project has CI workflows checked in',
      pass: hasFileWithExtension(rootDir, '.github/workflows', ['.yml', '.yaml']),
      fix: 'Add at least one CI workflow so harness and test checks run outside local development.',
    },
    {
      id: 'consumer-memory-notes',
      category: 'Memory Persistence',
      points: 2,
      scopes: ['repo'],
      path: '.claude/memory.md',
      description: 'Project memory or durable notes are checked in',
      pass: fileExists(rootDir, '.claude/memory.md') || countFiles(rootDir, 'docs/adr', '.md') > 0,
      fix: 'Add durable project memory such as .claude/memory.md or ADRs under docs/adr/.',
    },
    {
      id: 'consumer-eval-coverage',
      category: 'Eval Coverage',
      points: 2,
      scopes: ['repo'],
      path: 'evals/',
      description: 'The project has evals or multiple automated tests',
      pass: countFiles(rootDir, 'evals', null) > 0 || countFiles(rootDir, 'tests', '.test.js') >= 3,
      fix: 'Add eval fixtures or at least a few focused automated tests for critical flows.',
    },
    {
      id: 'consumer-security-policy',
      category: 'Security Guardrails',
      points: 2,
      scopes: ['repo'],
      path: 'SECURITY.md',
      description: 'The project exposes a security policy or automated dependency scanning',
      pass: fileExists(rootDir, 'SECURITY.md') || fileExists(rootDir, '.github/dependabot.yml') || fileExists(rootDir, '.github/codeql.yml'),
      fix: 'Add SECURITY.md or dependency/code scanning configuration to document the project security posture.',
    },
    {
      id: 'consumer-secret-hygiene',
      category: 'Security Guardrails',
      points: 2,
      scopes: ['repo'],
      path: '.gitignore',
      description: 'The project ignores common secret env files',
      pass: gitignore.includes('.env'),
      fix: 'Ignore .env-style files in .gitignore so secrets do not land in the repo.',
    },
    {
      id: 'consumer-hook-guardrails',
      category: 'Security Guardrails',
      points: 2,
      scopes: ['repo', 'hooks'],
      path: '.claude/settings.json',
      description: 'Project-local hook settings reference tool/prompt guardrails',
      pass: projectHooks.includes('PreToolUse') || projectHooks.includes('beforeSubmitPrompt') || fileExists(rootDir, '.claude/hooks.json'),
      fix: 'Add project-local hook settings or hook definitions for prompt/tool guardrails.',
    },
  ];
}

function summarizeCategoryScores(checks) {
  const scores = {};
  for (const category of CATEGORIES) {
    const inCategory = checks.filter(check => check.category === category);
    const max = inCategory.reduce((sum, check) => sum + check.points, 0);
    const earned = inCategory
      .filter(check => check.pass)
      .reduce((sum, check) => sum + check.points, 0);

    const normalized = max === 0 ? 0 : Math.round((earned / max) * 10);
    scores[category] = {
      score: normalized,
      earned,
      max,
    };
  }

  return scores;
}

function buildReport(scope, options = {}) {
  const rootDir = path.resolve(options.rootDir || process.cwd());
  const targetMode = options.targetMode || detectTargetMode(rootDir);
  const checks = (targetMode === 'repo' ? getRepoChecks(rootDir) : getConsumerChecks(rootDir))
    .filter(check => check.scopes.includes(scope));
  const categoryScores = summarizeCategoryScores(checks);
  const maxScore = checks.reduce((sum, check) => sum + check.points, 0);
  const overallScore = checks
    .filter(check => check.pass)
    .reduce((sum, check) => sum + check.points, 0);

  const failedChecks = checks.filter(check => !check.pass);
  const topActions = failedChecks
    .sort((left, right) => right.points - left.points)
    .slice(0, 3)
    .map(check => ({
      action: check.fix,
      path: check.path,
      category: check.category,
      points: check.points,
    }));

  return {
    scope,
    root_dir: rootDir,
    target_mode: targetMode,
    deterministic: true,
    rubric_version: '2026-03-30',
    overall_score: overallScore,
    max_score: maxScore,
    categories: categoryScores,
    checks: checks.map(check => ({
      id: check.id,
      category: check.category,
      points: check.points,
      path: check.path,
      description: check.description,
      pass: check.pass,
    })),
    top_actions: topActions,
  };
}

function printText(report) {
  console.log(`Harness Audit (${report.scope}, ${report.target_mode}): ${report.overall_score}/${report.max_score}`);
  console.log(`Root: ${report.root_dir}`);
  console.log('');

  for (const category of CATEGORIES) {
    const data = report.categories[category];
    if (!data || data.max === 0) {
      continue;
    }

    console.log(`- ${category}: ${data.score}/10 (${data.earned}/${data.max} pts)`);
  }

  const failed = report.checks.filter(check => !check.pass);
  console.log('');
  console.log(`Checks: ${report.checks.length} total, ${failed.length} failing`);

  if (failed.length > 0) {
    console.log('');
    console.log('Top 3 Actions:');
    report.top_actions.forEach((action, index) => {
      console.log(`${index + 1}) [${action.category}] ${action.action} (${action.path})`);
    });
  }
}

function showHelp(exitCode = 0) {
  console.log(`
Usage: node scripts/harness-audit.js [scope] [--scope <repo|hooks|skills|commands|agents>] [--format <text|json>]
       [--root <path>]

Deterministic harness audit based on explicit file/rule checks.
Audits the current working directory by default and auto-detects bstack repo mode vs consumer-project mode.
`);
  process.exit(exitCode);
}

function main() {
  try {
    const args = parseArgs(process.argv);

    if (args.help) {
      showHelp(0);
      return;
    }

    const report = buildReport(args.scope, { rootDir: args.root });

    if (args.format === 'json') {
      console.log(JSON.stringify(report, null, 2));
    } else {
      printText(report);
    }
  } catch (error) {
    console.error(`Error: ${error.message}`);
    process.exit(1);
  }
}

const isMain = process.argv[1] && fileURLToPath(import.meta.url) === path.resolve(process.argv[1]);
if (isMain) {
  main();
}

export { buildReport, parseArgs };
