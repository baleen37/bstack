---
name: harness-audit
description: Run a deterministic repository harness audit and return a prioritized scorecard. Use when evaluating harness quality, checking configuration coverage, or auditing security guardrails.
---

# Harness Audit

Run a deterministic repository harness audit and return a prioritized scorecard.

## Usage

`/harness-audit [scope] [--format text|json] [--root path]`

- `scope` (optional): `repo` (default), `hooks`, `skills`, `commands`, `agents`
- `--format`: output style (`text` default, `json` for automation)
- `--root`: audit a specific path instead of the current working directory

## How It Works

Run the deterministic audit script:

```bash
node "${CLAUDE_PLUGIN_ROOT}/scripts/harness-audit.js" [scope] --format [text|json] [--root path]
```

If `CLAUDE_PLUGIN_ROOT` is not set, use the script path relative to this plugin's root directory.

The script auto-detects whether the target is the bstack repo itself or a consumer project.

## Categories (7, each 0-10)

1. **Tool Coverage** — hooks, plugins, skills, agents
2. **Context Efficiency** — CLAUDE.md, AGENTS.md, README
3. **Quality Gates** — tests, CI, pre-commit, linting
4. **Memory Persistence** — .claude/, docs/
5. **Eval Coverage** — eval skills, test files
6. **Security Guardrails** — .gitignore, husky, commitlint, pre-commit
7. **Cost Efficiency** — semantic-release, nix, package scripts

## Output

1. `overall_score` / `max_score` (70 for repo scope)
2. Per-category scores
3. Failed checks with file paths
4. Top 3 prioritized actions
5. Rubric version: `2026-03-30`

## Checklist

- Use script output directly — do not rescore manually
- If `--format json`: return JSON unchanged
- If `--format text`: summarize failing checks and top actions
- Include exact file paths from output
