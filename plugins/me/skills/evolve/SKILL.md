---
name: evolve
description: Use when asked to "evolve skill", "스킬 개선", "회고", or "analyze this session". Reads the current session's transcript jsonl, extracts user corrections / verbose exploration / success patterns, and proposes patches to SKILL.md / AGENTS.md / CLAUDE.md one at a time with explicit user approval and individual commits.
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
  - Agent
---

# /me:evolve — Transcript 기반 Skill·Doc 진화

세션 transcript에서 개선 신호를 추출해 SKILL.md / AGENTS.md / CLAUDE.md에 patch를 제안한다. 한 건씩 사용자 승인 → Edit → 개별 commit.

## When to run

사용자가 명시적으로 호출했을 때만. 자동 트리거 없음.

```
/me:evolve                          현재 세션 회고
/me:evolve --skill me:research      해당 스킬에 집중
/me:evolve --session <id>           특정 세션 ID
/me:evolve --dry-run                제안만, 적용 안 함
```

## What this skill does NOT do

- raw transcript를 메인 에이전트가 직접 읽지 않는다 (컨텍스트 폭발 방지)
- 외부 플러그인 캐시(`~/.claude/plugins/cache/`)는 수정 안 한다 (upstream 제안 파일에만 누적)
- 새 스킬을 만들지 않는다 (`writing-skills` 영역)
- 자동 commit·push 안 한다 (반드시 사용자가 한 건씩 승인)

## Phase 0 — 인덱스 빌드

`build-index.ts`를 실행하면 transcript 자동 탐지, dirty tree 가드, 인덱싱이 한 번에 끝난다. 사용자가 path를 따로 지정할 필요 없다.

```bash
bun "${CLAUDE_PLUGIN_ROOT}/skills/evolve/scripts/build-index.ts" [--session <id>] [--skill <name>]
```

종료 코드: `0`=정상, `13`=dirty tree (commit 또는 stash 후 재시도), `14`=transcript 또는 project dir을 못 찾음.

stdout JSON을 변수에 캡처. **사용자에게 보여주지 말 것** — 다음 단계 서브에이전트에게만 전달.

인덱스의 `groups`가 비어 있으면: "이 세션에서는 개선 신호를 못 찾았어요" 출력 후 종료.

## Phase 1 — 서브에이전트 분석 (Agent)

서브에이전트(`general-purpose`)를 1개 디스패치한다. 프롬프트에 다음을 모두 포함:

1. spec 경로: `docs/superpowers/specs/2026-05-27-evolve-skill-design.md`
2. Phase 0에서 받은 인덱스 JSON 전체
3. 후보 파일 매핑 표 (아래 그대로 복사):

   | 신호 패턴 | 1순위 후보 | 2순위 |
   |---|---|---|
   | 스킬 미발견 / "이 스킬 안 쓰네" | 해당 SKILL.md (description, 트리거 키워드) | 가까운 AGENTS.md |
   | 스킬 invoke 후에도 규칙 위반 | 해당 SKILL.md (본문, Red Flags 섹션) | — |
   | 장황한 탐색 + 결국 X를 찾음 | 가까운 AGENTS.md (Key Files / Subdirectories) | CLAUDE.md |
   | 프로젝트 룰/관례 위반 | 가까운 CLAUDE.md | AGENTS.md |
   | 성공 패턴 | 자주 호출된 SKILL.md | — |

4. 출력 스키마: 아래 형식의 JSON 한 덩어리만, 다른 텍스트 없이.

   ```json
   {
     "proposals": [
       {
         "id": "P1",
         "signal_ids": ["S1"],
         "target_file": "<absolute path>",
         "is_external_cache": false,
         "change_kind": "edit",
         "patch": "<unified diff applicable with `git apply`>",
         "rationale": "1~2문장"
       }
     ],
     "skipped_signals": [{"id": "S3", "reason": "신뢰도 낮음"}]
   }
   ```

5. 지시: "트리만 보고 시작. 필요할 때만 `Bash`로 jsonl의 해당 turn 범위를 발췌해 깊이 분석. 메인 transcript는 절대 통째 읽지 말 것. 결과 JSON만 반환."

## Phase 2 — 적용 루프

서브에이전트 반환 JSON 파싱 후:

1. `is_external_cache: true` 인 proposal은 분리해 `docs/superpowers/evolutions/YYYY-MM-DD-upstream-suggestions.md`에 append (없으면 생성). Edit 시도 안 함.
2. 나머지 proposal을 1번부터 차례로 사용자에게 제시:

   ```
   P1. <target_file>
     근거: <signal_ids> (snippet)
     이유: <rationale>

     [patch diff]

     적용? [y / n / skip / edit]
   ```

3. 사용자 응답에 따라:
   - **y**: patch를 임시 파일에 쓰고 `apply-patch.sh` 호출:

     ```bash
     bash "${CLAUDE_PLUGIN_ROOT}/skills/evolve/scripts/apply-patch.sh" \
       "<target_file>" "<patch-file>" "<subject>" "<snippet>" "<session-id>"
     ```

     stdout의 short sha를 누적 목록에 기록.
   - **edit**: 사용자에게 patch 편집 기회 제공 후 y와 동일하게 처리.
   - **skip / n**: 다음 proposal로.

4. `--dry-run` 인자가 있으면 Phase 2 전체 스킵, proposal 목록만 출력.

5. 마무리: 적용된 commit sha 목록과 upstream 파일 경로 출력.

## Safety

- 시작 시 `git status --porcelain`이 비어 있어야 함 (dirty면 거부)
- 외부 캐시 차단은 `apply-patch.sh`가 한 번 더 강제 (이중 가드)
- patch는 적용 전 반드시 사용자에게 diff로 보여주기
- 각 변경은 별도 commit → `git revert <sha>` 한 줄로 개별 롤백 가능
