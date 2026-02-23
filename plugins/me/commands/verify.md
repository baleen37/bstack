---
name: verify
description: Run comprehensive verification on current codebase state
argument-hint: [quick|full|pre-commit|pre-pr]
---

# Verify - Comprehensive Codebase Verification

Execute a complete verification suite to ensure code quality, correctness, and readiness for commits or pull requests.

## Your Task

Run verification checks in the exact order specified below. Stop immediately if critical checks fail.

### Verification Sequence

Execute these checks in order:

#### 1. Build Check

- Run the project's build command
- If build fails, report errors and STOP
- Do not proceed with other checks until build passes

#### 2. Type Check

- Run TypeScript or type checker (if applicable)
- Report all type errors with file:line locations
- Count total errors

#### 3. Lint Check

- Run project linter (ESLint, Pylint, etc.)
- Report warnings and errors
- Include file:line locations for issues

#### 4. Test Suite

- Run all tests
- Report pass/fail count
- Report test coverage percentage
- List any failing tests with details

#### 5. Console.log Audit

- Search for console.log statements in source files
- Report locations (file:line)
- Exclude test files and configuration files
- Note: console.log in production code should be removed

#### 6. Git Status

- Show uncommitted changes
- List modified files since last commit
- Report untracked files
- Check for files staged for commit

### Verification Modes

The `$ARGUMENTS` parameter can specify different verification levels:

**`quick`** - Fast verification
- Build check
- Type check only

**`full`** - Complete verification (default)
- All checks listed above

**`pre-commit`** - Commit-relevant checks
- Build check
- Type check
- Lint check
- Test suite

**`pre-pr`** - Pull request readiness
- All checks from `full`
- Additional security scan (if available)
- Check for TODO/FIXME comments
- Verify no debug code

### Output Format

Produce a concise verification report in this format:

```
VERIFICATION: [PASS/FAIL]

Build: [OK/FAIL]
Types: [OK/X errors]
Lint: [OK/X issues]
Tests: [X/Y passed, Z% coverage]
Logs: [OK/X console.logs found]
Git: [Clean/X modified files]

Ready for PR: [YES/NO]
```

### Critical Issues Reporting

If any critical issues exist:

1. List each issue with:
   - File and line number
   - Description of the problem
   - Suggested fix (if applicable)

2. Categorize by severity:
   - **CRITICAL**: Build failures, type errors, test failures
   - **WARNING**: Lint issues, console.logs, missing coverage
   - **INFO**: Uncommitted changes, TODOs

### Decision Rules

**PASS criteria:**
- Build succeeds
- No type errors
- All tests pass
- No critical lint errors
- Test coverage meets threshold (if configured)

**FAIL criteria:**
- Build fails
- Type errors present
- Tests fail
- Critical lint errors

**Ready for PR:**
- All PASS criteria met
- No console.logs in source code (warnings allowed)
- Git working directory clean or changes are intentional
- Test coverage adequate

### Example Invocations

**Quick verification:**
```
/verify quick
```

**Full verification:**
```
/verify full
```
or simply:
```
/verify
```

**Pre-commit check:**
```
/verify pre-commit
```

**Pre-PR check:**
```
/verify pre-pr
```

## Implementation Notes

### Finding Build Commands

Look for build commands in:
- `package.json` scripts: `build`, `compile`
- `Makefile`: `build` target
- Project-specific build tools (Gradle, Maven, etc.)

### Finding Type Checkers

Common type check commands:
- TypeScript: `tsc --noEmit`
- Python: `mypy`
- Package.json: `type-check` script

### Finding Linters

Common lint commands:
- JavaScript/TypeScript: `eslint`
- Python: `pylint`, `flake8`, `ruff`
- Package.json: `lint` script

### Finding Test Commands

Common test commands:
- JavaScript: `bun test`, `npm test`, `jest`, `vitest`
- Python: `pytest`, `python -m unittest`
- Package.json: `test` script

### Console.log Detection

Use grep or similar to find console.log:
```bash
# Exclude test files and node_modules
grep -r "console\.log" src/ --exclude-dir=node_modules
```

Note: In Bun projects, `node_modules` may be less relevant as Bun uses a different module resolution and caching system.

## Best Practices

- **Run verification before commits**: Catch issues early
- **Run full verification before PRs**: Ensure quality
- **Fix critical issues first**: Don't ignore build/test failures
- **Use quick mode during development**: Fast feedback loop
- **Automate in CI**: Verify on every push

## Error Handling

If verification fails:
1. Report which check failed
2. Provide actionable error messages
3. Suggest next steps to fix
4. Do not proceed with subsequent checks if critical checks fail (build, tests)

## Important Notes

- Verification should be non-destructive (no code changes)
- Report findings clearly and concisely
- Prioritize critical issues over warnings
- Be specific about file locations for issues
- Verification results should be deterministic
