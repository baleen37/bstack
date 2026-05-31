# autoresearch 독립 plugin 복원 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `/goal` 의존으로 깨진 me-통합 autoresearch를, `/goal`을 안 쓰는 옛 독립 `plugins/autoresearch/` plugin으로 복원한다.

**Architecture:** #660(`efa9cdf4`) 직전 상태(`efa9cdf4~1`)에서 옛 plugin 6개 파일을 `git show`로 추출 복원하고, me 쪽 통합물(SKILL.md + README 행)을 제거한 뒤, marketplace.json·버전·README 표를 현재 상태에 맞춰 정합화한다. `git revert`는 이후 release 커밋들의 marketplace 충돌 때문에 쓰지 않는다.

**Tech Stack:** git (파일 추출), jq (JSON 검증), bash hook, Claude Code plugin 구조

---

## File Structure

복원 (모두 `efa9cdf4~1`에서 추출):
- `plugins/autoresearch/.claude-plugin/plugin.json` — plugin 메타 (version만 17.16.2로 수정)
- `plugins/autoresearch/.codex-plugin/plugin.json` — codex 메타 (version만 17.16.2로 수정)
- `plugins/autoresearch/commands/autoresearch.md` — `/autoresearch [off|goal]` 명령
- `plugins/autoresearch/hooks/hooks.json` — UserPromptSubmit hook 등록
- `plugins/autoresearch/hooks/autoresearch-context.sh` — NEVER STOP 컨텍스트 주입 (실행권한 필요)
- `plugins/autoresearch/skills/autoresearch/SKILL.md` — hook 기반 스킬 (253줄, /goal 없음)

제거:
- `plugins/me/skills/autoresearch/SKILL.md` — me 통합물

수정:
- `.claude-plugin/marketplace.json` — autoresearch 항목 추가
- `README.md` — me 표에서 autoresearch 행 제거 + autoresearch plugin 표 섹션 추가

---

## Task 1: 옛 plugin 파일 6개 추출 복원

**Files:**
- Create: `plugins/autoresearch/.claude-plugin/plugin.json`
- Create: `plugins/autoresearch/.codex-plugin/plugin.json`
- Create: `plugins/autoresearch/commands/autoresearch.md`
- Create: `plugins/autoresearch/hooks/hooks.json`
- Create: `plugins/autoresearch/hooks/autoresearch-context.sh`
- Create: `plugins/autoresearch/skills/autoresearch/SKILL.md`

- [ ] **Step 1: 디렉토리 생성 + 6개 파일 추출**

Run:
```bash
cd "$(git rev-parse --show-toplevel)"
REF=efa9cdf4~1
mkdir -p plugins/autoresearch/.claude-plugin \
         plugins/autoresearch/.codex-plugin \
         plugins/autoresearch/commands \
         plugins/autoresearch/hooks \
         plugins/autoresearch/skills/autoresearch
for f in \
  .claude-plugin/plugin.json \
  .codex-plugin/plugin.json \
  commands/autoresearch.md \
  hooks/hooks.json \
  hooks/autoresearch-context.sh \
  skills/autoresearch/SKILL.md ; do
  git show "$REF:plugins/autoresearch/$f" > "plugins/autoresearch/$f"
done
```

- [ ] **Step 2: 추출 검증 (6개 파일 존재 + 비어있지 않음)**

Run:
```bash
for f in .claude-plugin/plugin.json .codex-plugin/plugin.json commands/autoresearch.md hooks/hooks.json hooks/autoresearch-context.sh skills/autoresearch/SKILL.md; do
  test -s "plugins/autoresearch/$f" && echo "OK $f" || echo "MISSING/EMPTY $f"
done
```
Expected: 6줄 모두 `OK`

- [ ] **Step 3: hook 스크립트 실행권한 부여**

Run:
```bash
chmod +x plugins/autoresearch/hooks/autoresearch-context.sh
test -x plugins/autoresearch/hooks/autoresearch-context.sh && echo "executable" || echo "FAIL"
```
Expected: `executable`

- [ ] **Step 4: SKILL.md에 /goal 참조가 없는지 확인 (옛 hook 버전 맞는지)**

Run:
```bash
grep -c '/goal' plugins/autoresearch/skills/autoresearch/SKILL.md || true
grep -c 'NEVER STOP\|Loop forever\|loop forever' plugins/autoresearch/hooks/autoresearch-context.sh
```
Expected: 첫 줄 `0` (SKILL.md에 /goal 없음), 둘째 줄 `1` 이상 (옛 hook 버전 확인)

- [ ] **Step 5: 커밋**

```bash
git add plugins/autoresearch/
git commit -m "feat(autoresearch): restore standalone plugin files from efa9cdf4~1

Extract the pre-#660 plugin (commands, UserPromptSubmit hook, skill)
which uses a hook instead of the unrunnable /goal command."
```

---

## Task 2: 두 plugin.json version을 17.16.2로 정합화

**Files:**
- Modify: `plugins/autoresearch/.claude-plugin/plugin.json` (`"version": "17.11.2"` → `"17.16.2"`)
- Modify: `plugins/autoresearch/.codex-plugin/plugin.json` (동일)

- [ ] **Step 1: 현재 version 확인**

Run:
```bash
grep '"version"' plugins/autoresearch/.claude-plugin/plugin.json plugins/autoresearch/.codex-plugin/plugin.json
```
Expected: 둘 다 `"version": "17.11.2"`

- [ ] **Step 2: 두 파일 version을 17.16.2로 치환**

Run:
```bash
for f in plugins/autoresearch/.claude-plugin/plugin.json plugins/autoresearch/.codex-plugin/plugin.json; do
  tmp=$(mktemp)
  jq '.version = "17.16.2"' "$f" > "$tmp" && mv "$tmp" "$f"
done
```

- [ ] **Step 3: 검증 — version 통일 + JSON 유효**

Run:
```bash
grep '"version"' plugins/autoresearch/.claude-plugin/plugin.json plugins/autoresearch/.codex-plugin/plugin.json
jq -e . plugins/autoresearch/.claude-plugin/plugin.json >/dev/null && echo "claude json OK"
jq -e . plugins/autoresearch/.codex-plugin/plugin.json >/dev/null && echo "codex json OK"
```
Expected: 두 version 모두 `17.16.2`, `claude json OK`, `codex json OK`

- [ ] **Step 4: 커밋**

```bash
git add plugins/autoresearch/.claude-plugin/plugin.json plugins/autoresearch/.codex-plugin/plugin.json
git commit -m "chore(autoresearch): align plugin version to 17.16.2"
```

---

## Task 3: me 통합 SKILL.md 제거

**Files:**
- Delete: `plugins/me/skills/autoresearch/SKILL.md` (및 빈 디렉토리)

- [ ] **Step 1: 제거 대상 존재 확인**

Run:
```bash
test -f plugins/me/skills/autoresearch/SKILL.md && echo "exists, will remove" || echo "already gone"
```
Expected: `exists, will remove`

- [ ] **Step 2: git에서 제거**

Run:
```bash
git rm plugins/me/skills/autoresearch/SKILL.md
rmdir plugins/me/skills/autoresearch 2>/dev/null || true
```

- [ ] **Step 3: 검증 — me에 autoresearch 스킬 없음, 다른 me 스킬 영향 없음**

Run:
```bash
test -e plugins/me/skills/autoresearch && echo "FAIL still present" || echo "removed OK"
ls plugins/me/skills/ | grep -c autoresearch || echo "0 in me skills"
ls plugins/me/skills/ | wc -l
```
Expected: `removed OK`, autoresearch 없음, me 스킬 개수는 기존보다 1 적음 (23개)

- [ ] **Step 4: 커밋**

```bash
git add -A
git commit -m "chore(me): remove autoresearch skill (moved to standalone plugin)"
```

---

## Task 4: marketplace.json에 autoresearch 항목 추가

**Files:**
- Modify: `.claude-plugin/marketplace.json` (`plugins` 배열 끝에 항목 추가)

- [ ] **Step 1: 현재 plugin 개수 확인 (4개 예상)**

Run:
```bash
jq '.plugins | length' .claude-plugin/marketplace.json
```
Expected: `4`

- [ ] **Step 2: autoresearch 항목을 배열 끝에 추가**

Run:
```bash
tmp=$(mktemp)
jq '.plugins += [{
  "name": "autoresearch",
  "description": "Autonomous experiment loop — iteratively optimize any metric with git-tracked experiments",
  "source": "./plugins/autoresearch",
  "category": "development",
  "tags": ["experiments", "optimization", "autonomous", "research"],
  "version": "17.16.2"
}]' .claude-plugin/marketplace.json > "$tmp" && mv "$tmp" .claude-plugin/marketplace.json
```

- [ ] **Step 3: 검증 — 5개, autoresearch 존재, JSON 유효**

Run:
```bash
jq -e . .claude-plugin/marketplace.json >/dev/null && echo "json OK"
jq '.plugins | length' .claude-plugin/marketplace.json
jq -r '.plugins[] | select(.name=="autoresearch") | .source' .claude-plugin/marketplace.json
```
Expected: `json OK`, `5`, `./plugins/autoresearch`

- [ ] **Step 4: 커밋**

```bash
git add .claude-plugin/marketplace.json
git commit -m "chore(marketplace): register autoresearch plugin"
```

---

## Task 4b: codex marketplace 동기화 (구현 중 발견)

`.agents/plugins/marketplace.json`(codex marketplace)은 claude marketplace의 skill plugin들을 같은
순서로 미러해야 한다(`tests/codex_marketplace_json.bats`가 강제). Task 4가 claude marketplace만
갱신해 이 테스트가 깨졌으므로, codex marketplace에도 autoresearch를 추가하고 테스트의 하드코딩된
plugin count를 4→5로 갱신했다.

- Modify: `.agents/plugins/marketplace.json` (autoresearch 항목을 datadog 뒤에 추가)
- Modify: `tests/codex_marketplace_json.bats` (`[ "$plugin_count" -eq 4 ]` → `5`)
- 검증: `bats tests/codex_marketplace_json.bats` 4개 모두 통과
- 커밋: `fix(marketplace): sync autoresearch into codex marketplace`

---

## Task 5: README 스킬 표 정합화

**Files:**
- Modify: `README.md` (me 표 82번 행 제거 + autoresearch plugin 표 섹션 추가)

- [ ] **Step 1: me 표에서 autoresearch 행 제거**

`README.md`에서 아래 행을 삭제한다 (me plugin 스킬 표의 마지막 행, 82번 줄 부근):

```markdown
| `autoresearch` | /goal 종료 조건으로 자율 실험 루프 실행 |
```

- [ ] **Step 2: autoresearch plugin 표 섹션 추가**

`README.md`에서 `#### \`ralph\` plugin` 섹션 **바로 앞**에 아래 섹션을 삽입한다 (hook 기반 동작에 맞춘 설명 — `/goal` 표현 제거):

```markdown
#### `autoresearch` plugin

| Skill | Description |
|-------|-------------|
| `autoresearch` | git 추적 실험으로 metric을 반복 최적화하는 자율 실험 루프 |

```

- [ ] **Step 3: 검증 — /goal 표현 제거됨, autoresearch 섹션 존재**

Run:
```bash
grep -n "autoresearch" README.md
grep -c "/goal 종료 조건으로 자율 실험" README.md || echo "0 (old line removed)"
```
Expected: `autoresearch` plugin 표 섹션에 행 존재, 옛 `/goal 종료 조건으로...` 행은 `0`

- [ ] **Step 4: 커밋**

```bash
git add README.md
git commit -m "docs(readme): move autoresearch to its own plugin section"
```

---

## Task 6: 전체 검증

- [ ] **Step 1: autoresearch 잔존 참조 전수 점검 (/goal 누수 없음)**

Run:
```bash
cd "$(git rev-parse --show-toplevel)"
echo "--- /goal 참조가 복원 plugin에 없어야 함 ---"
grep -rn "/goal" plugins/autoresearch/ && echo "FAIL: /goal found" || echo "OK no /goal"
echo "--- me에 autoresearch 잔존 없어야 함 ---"
test -e plugins/me/skills/autoresearch && echo "FAIL" || echo "OK"
echo "--- marketplace 유효 ---"
jq -e . .claude-plugin/marketplace.json >/dev/null && echo "OK"
```
Expected: `OK no /goal`, `OK`, `OK`

- [ ] **Step 2: pre-commit 전체 실행**

Run:
```bash
pre-commit run --all-files
```
Expected: 모든 hook PASS (shellcheck가 autoresearch-context.sh, json 검사 등 통과)

- [ ] **Step 3: bats 테스트 (plugin 구조 검증)**

Run:
```bash
bats tests/ 2>&1 | tail -20
```
Expected: 실패 없음. (autoresearch 관련 구조 테스트가 있으면 통과; 무관하면 회귀 없음 확인)

- [ ] **Step 4: 변경 요약 확인 후 최종 상태 점검**

Run:
```bash
git log --oneline -6
git status --short
```
Expected: Task 1~5 커밋들 존재, working tree clean

---

## Self-Review (작성자 점검 완료)

- **Spec coverage:** 복원 6파일(T1) / version 정합(T2) / me 제거(T3) / marketplace(T4) / README(T5) / 검증(T6) — spec의 복원·제거·marketplace·버전·성공기준 전 항목 매핑됨.
- **Placeholder:** 없음. 모든 step에 실제 명령·기대출력 명시.
- **Type/이름 일관성:** 파일 경로·plugin name(`autoresearch`)·version(`17.16.2`)·source(`./plugins/autoresearch`) 전 태스크 일관.
- **검증 누락:** spec 성공기준(실행권한·jq 유효·/goal 부재·테스트)을 T1 Step3, T2 Step3, T4 Step3, T6에 각각 배치.
