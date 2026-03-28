---
name: project-setup
description: Use when setting up a new project repository, initializing CI/CD, configuring branch protection, or the user asks to scaffold project infrastructure
---

# Project Setup Checklist

New project setup checklist. Verify each item and configure what's missing.

## Checklist

### 1. Branch Protection

- [ ] `main` branch direct push is disabled
- [ ] PRs require at least 0 approvals (optional; configure based on team size)
- [ ] All CI status checks must pass before merge
- [ ] Configure via GitHub branch protection rules or repo settings

### 2. CI (GitHub Actions)

- [ ] CI workflow exists (`.github/workflows/`)
- [ ] Runs on PR and push to main
- [ ] If org is `wooto`: must use `runs-on: self-hosted` (wooto org runner has no custom labels, matches on `self-hosted` only)
- [ ] All tests run in CI
- [ ] Lint/format checks run in CI

### 3. Pre-commit Testing

- [ ] Pre-commit hooks configured (husky, pre-commit framework, or equivalent)
- [ ] Tests run on pre-commit (or at minimum pre-push)
- [ ] Hooks are not bypassable without explicit intent (`--no-verify` should be discouraged)

### 4. Basics

- [ ] `.gitignore` appropriate for project language/framework
- [ ] README exists with setup instructions
- [ ] Conventional Commits enforced (commitlint or equivalent)

## How to Use

1. Read the current repo state
2. Walk through each checklist item
3. Report what's already configured vs what's missing
4. Offer to set up missing items
