---
name: refactor-clean
description: "Safely identify and remove dead code with test verification. Detects unused code, dependencies, and files regardless of programming language or framework."
argument-hint: [<path>]
disable-model-invocation: true
---

Safely identify and remove dead code with test verification:

1. Detect dead code using appropriate tools for the codebase:
   - Detect unused exports, functions, classes, and modules
   - Find unused dependencies and imports
   - Identify unreferenced files and assets
   - Look for dead code patterns specific to the project's language

2. Generate comprehensive report in .reports/dead-code-analysis.md

3. Categorize findings by severity:
   - SAFE: Test files, unused utilities, commented code
   - CAUTION: API routes, components, modules that might be used dynamically
   - DANGER: Config files, main entry points, framework-specific files

4. Propose safe deletions only

5. Before each deletion:
   - Run full test suite
   - Verify tests pass
   - Apply change
   - Re-run tests
   - Rollback if tests fail

6. Show summary of cleaned items

Never delete code without running tests first!
