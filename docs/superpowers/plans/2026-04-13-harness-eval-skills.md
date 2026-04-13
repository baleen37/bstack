# Harness Eval Skills Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** ECC(everything-claude-code)에서 agent-eval, eval-harness 스킬과 harness-audit 커맨드를 bstack 플러그인에 포팅한다.

**Architecture:** `plugins/me/skills/`에 2개 스킬 추가, `scripts/`에 harness-audit.js 추가. ECC의 consumer 모드 체크를 활용하되, bstack 프로젝트 구조(plugins/, hooks/, tests/)에 맞게 체크 항목을 조정한다.

**Tech Stack:** Node.js (harness-audit.js), BATS (tests), Markdown (SKILL.md)

**Source:** MIT licensed [affaan-m/everything-claude-code](https://github.com/affaan-m/everything-claude-code) — cloned at `/tmp/everything-claude-code/`

---

### Task 1: agent-eval 스킬 추가

**Files:**
- Create: `plugins/me/skills/agent-eval/SKILL.md`

- [ ] **Step 1: SKILL.md 작성**

ECC의 `skills/agent-eval/SKILL.md`를 기반으로 bstack 스킬 컨벤션에 맞게 작성한다. `origin: ECC` → `origin: ECC (MIT)` 변경, `tools` 필드 제거 (bstack 컨벤션에 없음).

```bash
mkdir -p plugins/me/skills/agent-eval
```

`plugins/me/skills/agent-eval/SKILL.md` 내용은 ECC 원본에서 frontmatter를 bstack 패턴으로 조정:

```yaml
---
name: agent-eval
description: Head-to-head comparison of coding agents (Claude Code, Aider, Codex, etc.) on custom tasks with pass rate, cost, time, and consistency metrics
---
```

본문은 ECC 원본 그대로 유지 (YAML task definitions, git worktree isolation, metrics, judge types, best practices, links).

- [ ] **Step 2: frontmatter 검증**

```bash
head -5 plugins/me/skills/agent-eval/SKILL.md
# Expected:
# ---
# name: agent-eval
# description: Head-to-head comparison of coding agents...
# ---
```

- [ ] **Step 3: 커밋**

```bash
git add plugins/me/skills/agent-eval/SKILL.md
git commit -m "feat(skills): add agent-eval skill from ECC

Head-to-head comparison of coding agents on custom tasks.
Source: affaan-m/everything-claude-code (MIT)"
```

---

### Task 2: eval-harness 스킬 교체

현재 `plugins/me/skills/eval-harness/SKILL.md`는 A/B 비교 도구이다. 이것을 `variant-compare`로 이름을 바꾸고, ECC의 eval-harness (EDD 프레임워크)로 교체한다.

**Files:**
- Rename: `plugins/me/skills/eval-harness/SKILL.md` → `plugins/me/skills/variant-compare/SKILL.md`
- Create: `plugins/me/skills/eval-harness/SKILL.md` (새 내용)

- [ ] **Step 1: 기존 eval-harness를 variant-compare로 이동**

```bash
mkdir -p plugins/me/skills/variant-compare
mv plugins/me/skills/eval-harness/SKILL.md plugins/me/skills/variant-compare/SKILL.md
```

- [ ] **Step 2: variant-compare frontmatter 수정**

`plugins/me/skills/variant-compare/SKILL.md`의 frontmatter에서 name 변경:

```yaml
---
name: variant-compare
description: Use when comparing two variants (code, LLM prompts, CLI commands, or any executable) against defined criteria with the same inputs. Do NOT use when variants cannot produce observable, comparable output.
---
```

- [ ] **Step 3: 새 eval-harness 스킬 작성**

`plugins/me/skills/eval-harness/SKILL.md`에 ECC의 eval-harness를 기반으로 작성. frontmatter를 bstack 패턴으로 조정:

```yaml
---
name: eval-harness
description: Formal evaluation framework for Claude Code sessions implementing eval-driven development (EDD) principles
---
```

본문은 ECC 원본 유지 (Eval Types, Grader Types, Metrics, Eval Workflow, Integration Patterns, Product Evals 등).

- [ ] **Step 4: 검증**

```bash
# 두 파일 모두 존재 확인
ls plugins/me/skills/variant-compare/SKILL.md
ls plugins/me/skills/eval-harness/SKILL.md

# frontmatter 확인
grep "^name:" plugins/me/skills/variant-compare/SKILL.md
# Expected: name: variant-compare

grep "^name:" plugins/me/skills/eval-harness/SKILL.md
# Expected: name: eval-harness
```

- [ ] **Step 5: 커밋**

```bash
git add plugins/me/skills/variant-compare/SKILL.md plugins/me/skills/eval-harness/SKILL.md
git commit -m "feat(skills): replace eval-harness with EDD framework, rename old to variant-compare

- eval-harness: now EDD (eval-driven development) framework from ECC
- variant-compare: the original A/B comparison skill, renamed
Source: affaan-m/everything-claude-code (MIT)"
```

---

### Task 3: harness-audit.js 스크립트 추가

**Files:**
- Create: `scripts/harness-audit.js`

- [ ] **Step 1: ECC의 harness-audit.js를 복사**

```bash
cp /tmp/everything-claude-code/scripts/harness-audit.js scripts/harness-audit.js
```

- [ ] **Step 2: bstack 구조에 맞게 수정**

`scripts/harness-audit.js`에서 다음을 변경:

1. `detectTargetMode()`: bstack 패키지 이름 인식 추가

```javascript
// 기존: packageJson?.name === 'everything-claude-code'
// 변경: bstack도 repo 모드로 인식
if (packageJson?.name === 'everything-claude-code' || packageJson?.name === 'me') {
  return 'repo';
}
```

2. `getRepoChecks()`: bstack 구조에 맞게 체크 항목 수정

주요 변경:
- `hooks/hooks.json` → `plugins/*/hooks/` 경로 확인
- `scripts/hooks/*.js` → bstack에는 없으므로 제거 또는 경로 조정
- `agents/` → `plugins/*/agents/` 경로
- `skills/` → `plugins/*/skills/` 경로
- 스킬 개수 기준: 20 → 10 (bstack 규모에 맞게)
- 에이전트 개수 기준: 10 → 3
- `.opencode` 관련 체크 제거 (bstack에 없음)
- `tests/run-all.js` → `tests/run-all-tests.sh` (bstack은 BATS)
- `package.json` test 스크립트 체크: `validate-commands.js` → `run-all-tests.sh`

3. consumer 모드는 그대로 유지 (범용적이라 수정 불필요)

- [ ] **Step 3: 스크립트 실행 테스트**

```bash
node scripts/harness-audit.js --format text
# Expected: Harness Audit (repo, repo): XX/YY 형태 출력

node scripts/harness-audit.js --format json | head -5
# Expected: JSON 출력
```

- [ ] **Step 4: 커밋**

```bash
git add scripts/harness-audit.js
git commit -m "feat(scripts): add harness-audit.js from ECC, adapted for bstack

Deterministic harness audit with 7 categories.
Supports both repo mode (bstack itself) and consumer mode (user projects).
Source: affaan-m/everything-claude-code (MIT)"
```

---

### Task 4: harness-audit 스킬 (커맨드) 추가

**Files:**
- Create: `plugins/me/skills/harness-audit/SKILL.md`

- [ ] **Step 1: SKILL.md 작성**

ECC의 `.opencode/commands/harness-audit.md`를 기반으로 하되, bstack 스킬 형식으로 변환:

```yaml
---
name: harness-audit
description: Run a deterministic repository harness audit and return a prioritized scorecard. Use when evaluating harness quality, checking configuration coverage, or auditing security guardrails.
---
```

본문에서:
- `node scripts/harness-audit.js` 경로를 `node ${CLAUDE_PLUGIN_ROOT}/scripts/harness-audit.js`로 변경 (플러그인 포터블 경로)
- 7개 카테고리 설명 유지
- 사용법, 출력 계약, 예시 유지

- [ ] **Step 2: 검증**

```bash
head -5 plugins/me/skills/harness-audit/SKILL.md
grep "harness-audit.js" plugins/me/skills/harness-audit/SKILL.md
```

- [ ] **Step 3: 커밋**

```bash
git add plugins/me/skills/harness-audit/SKILL.md
git commit -m "feat(skills): add harness-audit skill for deterministic harness scoring

7-category scorecard: Tool Coverage, Context Efficiency, Quality Gates,
Memory Persistence, Eval Coverage, Security Guardrails, Cost Efficiency.
Source: affaan-m/everything-claude-code (MIT)"
```

---

### Task 5: BATS 테스트 추가

**Files:**
- Create: `tests/skills/test_harness_eval_skills.bats`

- [ ] **Step 1: 테스트 파일 작성**

```bash
#!/usr/bin/env bats
# Test suite for harness-eval related skills

load '../helpers/bats_helper'

# agent-eval skill tests
@test "agent-eval SKILL.md exists" {
  [ -f "${PROJECT_ROOT}/plugins/me/skills/agent-eval/SKILL.md" ]
}

@test "agent-eval has valid frontmatter" {
  local file="${PROJECT_ROOT}/plugins/me/skills/agent-eval/SKILL.md"
  head -1 "$file" | grep -q "^---"
  grep -q "^name: agent-eval" "$file"
  grep -q "^description:" "$file"
}

# eval-harness skill tests
@test "eval-harness SKILL.md exists" {
  [ -f "${PROJECT_ROOT}/plugins/me/skills/eval-harness/SKILL.md" ]
}

@test "eval-harness has valid frontmatter" {
  local file="${PROJECT_ROOT}/plugins/me/skills/eval-harness/SKILL.md"
  head -1 "$file" | grep -q "^---"
  grep -q "^name: eval-harness" "$file"
  grep -q "^description:" "$file"
}

# variant-compare skill tests (renamed from old eval-harness)
@test "variant-compare SKILL.md exists" {
  [ -f "${PROJECT_ROOT}/plugins/me/skills/variant-compare/SKILL.md" ]
}

@test "variant-compare has valid frontmatter" {
  local file="${PROJECT_ROOT}/plugins/me/skills/variant-compare/SKILL.md"
  head -1 "$file" | grep -q "^---"
  grep -q "^name: variant-compare" "$file"
  grep -q "^description:" "$file"
}

# harness-audit skill tests
@test "harness-audit SKILL.md exists" {
  [ -f "${PROJECT_ROOT}/plugins/me/skills/harness-audit/SKILL.md" ]
}

@test "harness-audit has valid frontmatter" {
  local file="${PROJECT_ROOT}/plugins/me/skills/harness-audit/SKILL.md"
  head -1 "$file" | grep -q "^---"
  grep -q "^name: harness-audit" "$file"
  grep -q "^description:" "$file"
}

# harness-audit.js script tests
@test "harness-audit.js exists" {
  [ -f "${PROJECT_ROOT}/scripts/harness-audit.js" ]
}

@test "harness-audit.js runs without error" {
  run node "${PROJECT_ROOT}/scripts/harness-audit.js" --format text
  [ "$status" -eq 0 ]
}

@test "harness-audit.js json output is valid JSON" {
  run node "${PROJECT_ROOT}/scripts/harness-audit.js" --format json
  [ "$status" -eq 0 ]
  echo "$output" | node -e "JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'))"
}

@test "harness-audit.js supports scope argument" {
  run node "${PROJECT_ROOT}/scripts/harness-audit.js" hooks --format text
  [ "$status" -eq 0 ]
}
```

- [ ] **Step 2: 테스트 실행**

```bash
bats tests/skills/test_harness_eval_skills.bats
# Expected: 모든 테스트 PASS
```

- [ ] **Step 3: 커밋**

```bash
git add tests/skills/test_harness_eval_skills.bats
git commit -m "test(skills): add BATS tests for harness-eval skills and audit script"
```

---

### Task 6: 전체 테스트 통과 확인

- [ ] **Step 1: 전체 frontmatter 테스트**

```bash
bats tests/frontmatter_tests.bats
# Expected: 모든 SKILL.md 파일이 frontmatter 검증 통과
```

- [ ] **Step 2: 전체 테스트 스위트**

```bash
bats tests/
# Expected: 기존 테스트 + 새 테스트 모두 통과
```

- [ ] **Step 3: pre-commit hooks 통과 확인**

```bash
pre-commit run --all-files
# Expected: 모든 훅 통과
```
