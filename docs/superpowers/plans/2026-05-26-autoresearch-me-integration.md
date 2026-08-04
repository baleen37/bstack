# autoresearch → me plugin 통합 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `plugins/autoresearch/`를 폐기하고, `plugins/me/skills/autoresearch/SKILL.md` 단일 파일로 통합하면서 `/goal` Claude Code 명령어를 종료 조건 평가 메커니즘으로 채택한다.

**Architecture:** me plugin의 기존 패턴(commands 없이 description-based 자동 활성화)을 따라 단일 SKILL.md를 작성한다. 기존 JSONL state protocol, run.sh, dashboard, worklog, ideas backlog 등 검증된 핵심 메커니즘은 그대로 유지하되, "LOOP FOREVER. NEVER STOP." 정책과 UserPromptSubmit hook은 제거하고 `/goal`이 매 턴 종료 조건을 평가하도록 위임한다.

**Tech Stack:** Bash, Markdown, JSON, BATS (테스트), jq (검증)

**Spec:** `docs/superpowers/specs/2026-05-26-autoresearch-me-integration-design.md`

---

## File Structure

생성/수정/삭제 대상:

- **Create**: `plugins/me/skills/autoresearch/SKILL.md` — 단일 통합 skill 파일
- **Modify**: `.claude-plugin/marketplace.json` — autoresearch 엔트리 제거
- **Modify**: `.agents/plugins/marketplace.json` — autoresearch 엔트리 제거
- **Delete**: `plugins/autoresearch/` — 전체 디렉토리

---

## Task 1: 새 SKILL.md 작성 (단일 통합 파일)

**Files:**
- Create: `plugins/me/skills/autoresearch/SKILL.md`

- [ ] **Step 1: 디렉토리 생성**

```bash
mkdir -p plugins/me/skills/autoresearch
```

- [ ] **Step 2: SKILL.md 작성**

`plugins/me/skills/autoresearch/SKILL.md`에 아래 내용을 정확히 작성한다:

````markdown
---
name: autoresearch
description: Use when asked to "run autoresearch", "실험 루프", "optimize X iteratively", "start experiments", or "set up an experiment loop". Sets up an autonomous experiment loop with git-tracked iterations and /goal-driven termination.
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
---

# autoresearch: Autonomous experiment loop

자율 실험 루프: 가설을 시도하고, 잘 된 건 유지하고, 실패한 건 버린다. 종료 조건은 `/goal`이 매 턴 평가한다.

## When to use

- 사용자가 측정 가능한 metric을 반복 최적화하고자 할 때 (예: "parser perf R² 0.85까지", "테스트 통과 비율 100%까지")
- 이미 현재 디렉토리에 `.autoresearch/autoresearch.md`가 있으면 자동으로 resume 모드

## Prerequisites

- **Claude Code v2.1.139 이상** (`/goal` 명령어 사용)
- 워크스페이스 trust 수락됨
- `disableAllHooks` / `allowManagedHooksOnly` 미설정 (관련 시 `/goal`이 안내 메시지 출력)

## Flow

### Fresh start

1. 사용자에게 질문 (또는 인자에서 추론):
   - **Goal**: 무엇을 최적화하는지
   - **Command**: 벤치마크 실행 방법
   - **Metric**: 이름, 단위, lower/higher가 좋은지
   - **Files in scope**: 수정 가능한 파일
   - **Constraints**: 깨면 안 되는 것 (테스트 통과 등)
2. `git checkout -b autoresearch/<goal-slug>-<YYYY-MM-DD>`
3. 소스 파일 읽고 workload 이해
4. `.autoresearch/` 생성, 아래 파일 작성, 커밋:
   - `autoresearch.md` (Objective, Metrics, How to Run, Files in Scope, Off Limits, Constraints, What's Been Tried)
   - `run.sh` (`set -euo pipefail`, METRIC 출력)
   - `worklog.md` (세션 헤더)
5. JSONL config header 작성 → baseline 실행 → 첫 result line 작성 → dashboard 생성
6. **`/goal "<사용자 조건> OR <합리적 상한, 예: 100 experiments completed>"` 자동 설정**
7. /goal이 매 턴 평가 → 조건 미충족 시 자동으로 다음 실험 시작

### Resume

`.autoresearch/autoresearch.md`가 이미 존재하면:

1. `.autoresearch/autoresearch.md` 읽어 objective와 constraints 복원
2. `.autoresearch/autoresearch.jsonl` 읽어 상태 재구성:
   - 총 run 수, kept/discarded/crashed 수
   - 현재 segment의 baseline metric
   - 최고 metric과 해당 run
   - 추적 중인 secondary metric 식별
3. `git log --oneline -20`로 최근 커밋 확인
4. `.autoresearch/ideas.md`가 있으면 읽어 영감 활용
5. `.autoresearch/worklog.md`에서 narrative 복원
6. 이미 `/goal`이 active면 그대로 (Claude Code가 session resume 시 carry over함). 없으면 사용자 의도 확인 후 재설정.
7. 다음 실험으로 진행

## JSONL State Protocol

모든 실험 상태는 `.autoresearch/autoresearch.jsonl`에 append-only로 저장된다. 세션 간 재개의 source of truth.

### Config Header

파일의 첫 줄(과 각 재초기화 줄)은 config header:

```json
{"type":"config","name":"<session>","metricName":"<metric>","metricUnit":"<unit>","bestDirection":"lower|higher"}
```

규칙:
- 첫 줄은 항상 config header
- 추가 config header(재초기화) = 새 **segment** 시작. segment index는 매 config header마다 증가
- segment의 baseline은 해당 config header 이후 첫 result line

### Result Line

각 실험 결과는 한 줄의 JSON으로 append:

```json
{"run":1,"commit":"abc1234","metric":42.3,"metrics":{"secondary":123},"status":"keep","description":"baseline","timestamp":1234567890,"segment":0}
```

필드:
- `run`: 모든 segment 통합 1-indexed 일련번호
- `commit`: 7자 git short hash (keep은 auto-commit 이후, discard/crash는 현재 HEAD)
- `metric`: primary metric 값 (crash는 0)
- `metrics`: secondary metric 객체 — **추적 시작한 것은 이후 모든 결과에 포함**
- `status`: `keep` | `discard` | `crash`
- `description`: 시도한 변경 한 줄 요약
- `timestamp`: Unix epoch seconds
- `segment`: 현재 segment index

### 초기화

```bash
echo '{"type":"config","name":"<name>","metricName":"<metric>","metricUnit":"<unit>","bestDirection":"<lower|higher>"}' > .autoresearch/autoresearch.jsonl
```

재초기화(최적화 목표 변경)는 **append**:

```bash
echo '{"type":"config",...}' >> .autoresearch/autoresearch.jsonl
```

## Running Experiments

```bash
START_TIME=$(date +%s%N)
bash -c "./.autoresearch/run.sh" 2>&1 | tee /tmp/autoresearch-output.txt
EXIT_CODE=$?
END_TIME=$(date +%s%N)
DURATION=$(echo "scale=3; ($END_TIME - $START_TIME) / 1000000000" | bc)
echo "Duration: ${DURATION}s, Exit code: ${EXIT_CODE}"
```

이후:
- 출력에서 `METRIC name=number` 라인 파싱
- exit code != 0 → crash
- 출력 읽고 무슨 일이 있었는지 이해

## Logging Results

### 1. Status 판정

- **keep**: primary metric 개선 (`bestDirection=lower`면 더 작게, `higher`면 더 크게)
- **discard**: primary metric이 best kept보다 나쁘거나 같음
- **crash**: 명령 실패 (non-zero exit code)

Secondary metric은 모니터링용으로, 거의 keep/discard 결정에 영향 없음. primary 개선을 discard하는 경우는 secondary가 catastrophic 회귀했을 때만, 이유를 description에 명기.

### 2. Git ops

**keep:**

```bash
git add -A
git diff --cached --quiet && echo "nothing to commit" || git commit -m "<description>

Result: {\"status\":\"keep\",\"<metricName>\":<value>,<secondary metrics>}"
git rev-parse --short=7 HEAD
```

**discard 또는 crash:**

```bash
git checkout -- .
git clean -fd
```

commit 필드는 revert 이전의 HEAD hash 사용.

### 3. JSONL append

```bash
echo '{"run":<N>,"commit":"<hash>","metric":<value>,"metrics":{<secondaries>},"status":"<status>","description":"<desc>","timestamp":'$(date +%s)',"segment":<seg>}' >> .autoresearch/autoresearch.jsonl
```

### 4. Dashboard 재생성

매 log마다 `.autoresearch/dashboard.md` 갱신:

```markdown
# Autoresearch Dashboard: <name>

**Runs:** 12 | **Kept:** 8 | **Discarded:** 3 | **Crashed:** 1
**Baseline:** <metric_name>: <value><unit> (#1)
**Best:** <metric_name>: <value><unit> (#8, -26.2%)

| # | commit | <metric_name> | status | description |
|---|--------|---------------|--------|-------------|
| 1 | abc1234 | 42.3s | keep | baseline |
| 2 | def5678 | 40.1s (-5.2%) | keep | optimize hot loop |
| 3 | abc1234 | 43.0s (+1.7%) | discard | try vectorization |
```

각 metric 값에 baseline 대비 백분율 포함. 현재 segment의 모든 run 표시.

### 5. Worklog append

매 실험 후 `.autoresearch/worklog.md`에 entry append. context compaction과 crash에서도 살아남아 narrative 보존:

```markdown
### Run N: <short description> — <primary_metric>=<value> (<STATUS>)
- Timestamp: YYYY-MM-DD HH:MM
- What changed: <1-2 sentences>
- Result: <metric values>, <delta vs best>
- Insight: <무엇을 배웠는가>
- Next: <다음에 시도할 것>
```

세션 시작 시 worklog.md를 만들고 (헤더, data summary, baseline). resume 시 worklog.md를 읽어 컨텍스트 복원.

### 6. Secondary metric consistency

한 번 추적 시작한 secondary metric은 이후 모든 result에 포함시켜야 한다. JSONL을 파싱해 어떤 secondary가 추적 중인지 확인하고, 모두 present한지 보증. 도중에 새 secondary 추가는 OK — 그 시점부터 항상 포함.

## Termination

- `/goal`이 매 턴 종료 후 평가 → 조건 충족 시 자동 종료
- 사용자가 조기 종료하려면 `/goal clear` (`stop`, `off`, `reset`, `none`, `cancel`도 alias)
- "NEVER STOP" 정책 없음 — `/goal`이 종료 조건을 owns
- `.autoresearch/ideas.md`가 소진되면 final summary report 작성 후 자연 종료

## Ideas Backlog

복잡하지만 유망한 최적화를 발견했는데 지금 추구하지 않을 거면 `.autoresearch/ideas.md`에 bullet으로 append. 좋은 아이디어를 잃지 말 것.

루프가 멈췄을 때(/goal clear, context limit, crash 등) `.autoresearch/ideas.md`가 있으면:
1. ideas 파일을 읽고 영감으로 사용
2. 중복/이미 시도/명확히 나쁜 것 정리
3. 남은 아이디어 기반으로 실험 생성
4. 아무것도 남지 않으면 자체 새 아이디어 시도
5. 모든 경로 소진 시 `.autoresearch/ideas.md` 삭제하고 final summary 작성

`.autoresearch/ideas.md`가 없고 루프가 끝나면 연구 완료.

## User Steers

실험 실행 중 사용자가 보낸 메시지는 메모하고 **다음** 실험에 반영. 현재 실험 먼저 끝낼 것 — 멈추거나 확인 받지 말 것. 다음 실험에 사용자 아이디어 통합.

## autoresearch.md 갱신

`.autoresearch/autoresearch.md` — 특히 "What's Been Tried" 섹션 — 을 주기적으로 갱신해 fresh agent가 resume 시 무엇이 효과적이었고, 무엇이 안 됐고, 어떤 아키텍처 통찰을 얻었는지 완전한 컨텍스트를 갖도록. 5-10회 실험마다, 또는 의미 있는 돌파구마다.

## Red Flags

- "LOOP FOREVER" 정책을 자체적으로 강제하려 함 → `/goal`이 담당. 자체 무한 루프 정책 만들지 말 것
- `.autoresearch/off` sentinel 파일 만들기 → `/goal clear`로 대체. sentinel 사용하지 말 것
- UserPromptSubmit hook 추가 → `/goal`이 매 턴 자동 진행. hook 불필요
- secondary metric 누락 → 한 번 추적 시작한 것은 모든 result에 포함 필수
````

- [ ] **Step 3: 파일이 정상적으로 작성됐는지 확인**

```bash
ls -la plugins/me/skills/autoresearch/SKILL.md
head -10 plugins/me/skills/autoresearch/SKILL.md
```

Expected: 파일 존재, 첫 줄이 `---`, name과 description 포함.

- [ ] **Step 4: SKILL.md frontmatter 유효성 검증**

```bash
bats tests/frontmatter_tests.bats
```

Expected: 모든 테스트 통과.

- [ ] **Step 5: 커밋**

```bash
git add plugins/me/skills/autoresearch/SKILL.md
git commit -m "feat(me): add autoresearch skill with /goal integration

Autonomous experiment loop migrated from plugins/autoresearch/ to me plugin.
Termination owned by Claude Code /goal command instead of self-managed
'NEVER STOP' policy. JSONL state protocol, dashboard, worklog, ideas
backlog preserved."
```

---

## Task 2: marketplace.json에서 autoresearch 엔트리 제거

**Files:**
- Modify: `.claude-plugin/marketplace.json` (autoresearch 엔트리 제거)
- Modify: `.agents/plugins/marketplace.json` (autoresearch 엔트리 제거)

- [ ] **Step 1: `.claude-plugin/marketplace.json`에서 autoresearch 객체 제거**

기존 (lines 40-52):

```json
    {
      "name": "autoresearch",
      "description": "Autonomous experiment loop — iteratively optimize any metric with git-tracked experiments",
      "source": "./plugins/autoresearch",
      "category": "development",
      "tags": [
        "experiments",
        "optimization",
        "autonomous",
        "research"
      ],
      "version": "17.11.0"
    },
```

이 객체 전체를 제거하고 앞뒤 콤마/괄호를 맞춘다 (`{ "name": "autoresearch", ... },` 통째 삭제).

- [ ] **Step 2: `.agents/plugins/marketplace.json`에서 autoresearch 객체 제거**

기존 (lines 31-42):

```json
    {
      "name": "autoresearch",
      "source": {
        "source": "local",
        "path": "./plugins/autoresearch"
      },
      "policy": {
        "installation": "AVAILABLE",
        "authentication": "ON_INSTALL"
      },
      "category": "Productivity"
    },
```

이 객체 전체를 제거.

- [ ] **Step 3: 두 marketplace.json 모두 valid JSON인지 검증**

```bash
jq empty .claude-plugin/marketplace.json
jq empty .agents/plugins/marketplace.json
```

Expected: 오류 없음.

- [ ] **Step 4: marketplace 관련 BATS 테스트 실행**

```bash
bats tests/marketplace_json.bats
bats tests/codex_marketplace_json.bats
```

Expected: 모든 테스트 통과. autoresearch 엔트리 부재로 인한 실패가 없어야 함 (테스트는 plugins/ 디렉토리 스캔 기반).

- [ ] **Step 5: 커밋**

```bash
git add .claude-plugin/marketplace.json .agents/plugins/marketplace.json
git commit -m "chore: remove autoresearch entry from marketplace files

Skill migrated to plugins/me/skills/autoresearch/ — no longer a standalone plugin."
```

---

## Task 3: 기존 plugins/autoresearch/ 디렉토리 삭제

**Files:**
- Delete: `plugins/autoresearch/` (전체)

- [ ] **Step 1: 삭제 전 의존성 최종 확인**

```bash
grep -rn "plugins/autoresearch" . \
  --exclude-dir=node_modules \
  --exclude-dir=.git \
  --exclude-dir=docs \
  --exclude-dir=.worktrees \
  2>/dev/null
```

Expected: 마지막으로 남아 있는 참조가 없어야 함 (docs/ 내 spec/plan 문서 제외). 만약 결과가 나오면 그 위치의 참조를 먼저 제거.

- [ ] **Step 2: 디렉토리 제거**

```bash
git rm -r plugins/autoresearch
```

- [ ] **Step 3: 제거 검증**

```bash
ls plugins/autoresearch 2>&1
```

Expected: `No such file or directory`.

- [ ] **Step 4: plugin 구조 BATS 테스트 실행**

```bash
bats tests/plugin_json.bats
bats tests/codex_plugin_json.bats
bats tests/hooks_json.bats
```

Expected: 모든 테스트 통과. autoresearch 부재가 다른 plugin 검증을 깨뜨리지 않아야 함.

- [ ] **Step 5: 커밋**

```bash
git commit -m "chore: remove plugins/autoresearch directory

Skill migrated to plugins/me/skills/autoresearch/SKILL.md with /goal-driven
termination. Hooks (UserPromptSubmit context injection) no longer needed."
```

---

## Task 4: 통합 검증 (전체 테스트 실행)

**Files:** (변경 없음, 검증 전용)

- [ ] **Step 1: 전체 BATS 테스트 실행**

```bash
bats tests/
```

Expected: 모든 테스트 통과. autoresearch 제거 및 me/skills/autoresearch 추가로 인한 새 실패 없음.

- [ ] **Step 2: pre-commit hooks 실행**

```bash
pre-commit run --all-files
```

Expected: 모든 hook 통과 (yaml, json, shellcheck, markdownlint, commitlint).

- [ ] **Step 3: me plugin 디렉토리 구조 확인**

```bash
ls plugins/me/skills/autoresearch/
```

Expected: `SKILL.md` 단일 파일.

- [ ] **Step 4: skill frontmatter 다시 한번 확인**

```bash
head -10 plugins/me/skills/autoresearch/SKILL.md
```

Expected:
```
---
name: autoresearch
description: Use when asked to "run autoresearch", ...
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
---
```

- [ ] **Step 5: git status 깨끗한지 확인**

```bash
git status
```

Expected: `nothing to commit, working tree clean`.

- [ ] **Step 6: 최근 3개 커밋 확인**

```bash
git log --oneline -3
```

Expected: 세 개의 커밋(skill 추가, marketplace 정리, autoresearch 제거)이 순서대로 보임.

---

## 완료 기준

- [ ] `plugins/me/skills/autoresearch/SKILL.md` 존재, frontmatter 유효
- [ ] `plugins/autoresearch/` 디렉토리 부재
- [ ] 두 marketplace.json에 autoresearch 엔트리 없음
- [ ] 모든 BATS 테스트 통과
- [ ] pre-commit 통과
- [ ] SKILL.md가 200줄 이하 (원본 254줄 대비 단순화 입증)
- [ ] "NEVER STOP" / "LOOP FOREVER" 문구 없음
- [ ] hook 의존 없음 (UserPromptSubmit 등)
