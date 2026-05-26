# Spec: autoresearch를 me plugin에 통합 + /goal 연계

- **작성일**: 2026-05-26
- **상태**: design
- **관련 PR/이슈**: chore/revive-autoresearch 브랜치

## 배경

`plugins/autoresearch/`는 obra/autoresearch-claude-code의 fork로, autonomous experiment loop (목표 측정값을 향해 반복 실험하며 keep/discard) 기능을 제공한다.

조사 결과:
- **Upstream**은 2026-03-18 이후 변경 없음 (가져올 변경사항 없음)
- **Claude Code `/goal` 명령어** (v2.1.139+, prompt-based Stop hook의 session-scoped wrapper)가 현재 autoresearch의 핵심 메커니즘인 "턴 사이 자동 진행"을 깔끔하게 대체 가능
- 현재 plugin은 `UserPromptSubmit` hook으로 매번 컨텍스트를 주입하지만, 사용자 입력이 없으면 진행 안 됨 — 진짜 autonomous loop 아님
- `/goal`은 매 턴 종료 후 small fast model이 조건을 평가하고 자동으로 다음 턴 시작 → 진짜 autonomous

## 목표

1. autoresearch 기능을 `plugins/me/skills/autoresearch/`로 이전 (별도 plugin 폐기)
2. `/goal` 명령어를 종료 조건 평가 메커니즘으로 채택 — 자체 "NEVER STOP" 정책 제거
3. SKILL.md를 절반 이하로 단순화 (검증된 핵심 프로토콜만 유지)
4. hooks 폐기 (불필요)

## 비목표 (이번 작업에서 안 하는 것)

- JSONL state protocol 자체 변경 — 검증된 프로토콜 그대로 유지
- dashboard / worklog / ideas backlog 포맷 변경
- run.sh 구조 변경
- 외부 출처가 불확실한 패턴 (stagnation detector, explore/exploit flag 등) 도입 — 별도 작업으로 분리

## 설계

### 결과 디렉토리 구조

```
plugins/me/skills/autoresearch/
└── SKILL.md             # 단일 파일

plugins/autoresearch/    # 삭제
```

### SKILL.md frontmatter

```yaml
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
```

me plugin 다른 skill들 (handoff, qa, pickup 등)과 동일 패턴.

### SKILL.md 본문 구조

```
# autoresearch: Autonomous experiment loop

## When to use
- 사용자가 측정 가능한 metric을 반복 최적화하길 원할 때
- 이미 .autoresearch/ 디렉토리가 있으면 자동으로 resume 모드

## Prerequisites
- Claude Code v2.1.139 이상 (/goal 사용)
- Workspace trust 수락됨
- disableAllHooks / allowManagedHooksOnly 미설정

## Flow

### Fresh start
1. 사용자에게 질문 (또는 인자에서 추론): Goal, Command, Metric (+direction), Files in scope, Constraints
2. `git checkout -b autoresearch/<goal>-<date>`
3. 소스 파일 읽고 workload 이해
4. `.autoresearch/` 생성 + autoresearch.md, run.sh, worklog.md 작성 + 커밋
5. JSONL config header 작성 → baseline 실행 → result line 작성
6. **`/goal <user condition> OR N experiments completed` 설정**
7. /goal이 자동으로 다음 턴 진행

### Resume
- `.autoresearch/autoresearch.md` 존재하면 resume
- jsonl/worklog/ideas.md 읽어 상태 복원
- /goal은 session resume 시 자동 carry over (Claude Code 내장)

## JSONL State Protocol
[기존 그대로 — config header, result lines, segment 규칙]

## Running Experiments
[기존 그대로 — run.sh 호출, METRIC 파싱, 종료코드 판정]

## Logging Results
[기존 그대로 — keep/discard/crash 판정, git ops, jsonl append, dashboard, worklog]

## Dashboard
[기존 그대로]

## Ideas Backlog
[기존 그대로 — .autoresearch/ideas.md]

## Termination
- `/goal`이 매 턴 평가 → 조건 충족 시 자동 종료
- 조기 종료: 사용자가 `/goal clear`
- 더 이상 "LOOP FOREVER. NEVER STOP." 정책 없음
- ideas.md 소진 시 final summary report 작성 후 자연 종료
```

### 삭제 대상

| 항목 | 사유 |
|------|------|
| `plugins/autoresearch/` 전체 디렉토리 | me로 통합 |
| `plugins/autoresearch/commands/autoresearch.md` | SKILL.md 활성화로 대체 (me 패턴) |
| `plugins/autoresearch/hooks/autoresearch-context.sh` | /goal이 턴 사이 진행을 담당 |
| `plugins/autoresearch/hooks/hooks.json` | 위와 동일 |
| `.autoresearch/off` sentinel 관련 로직 | `/goal clear`로 대체 |
| "Loop forever / Never stop" 정책 문구 | /goal이 종료 조건 담당 |

### 유지 대상 (검증된 가치)

- JSONL state protocol (config header, segment 인덱싱, result fields)
- run.sh 패턴 (`set -euo pipefail`, METRIC 파싱)
- keep/discard/crash 판정 로직
- git commit/revert 흐름
- dashboard.md 자동 생성
- worklog.md narrative 누적
- ideas.md backlog
- User Steers (현재 실험 완료 후 다음 실험에 반영)
- Secondary metric consistency 규칙

### 호출 방식

me plugin은 commands 디렉토리 없이 SKILL의 description-based 자동 활성화를 사용한다. 다음 두 방식 모두 지원:

1. **Skill tool 자동 활성화**: 사용자가 "autoresearch 시작해줘", "실험 루프로 X 최적화하자" 등의 자연어 메시지 → Claude가 description 매칭으로 skill 호출
2. **`/me:autoresearch <goal>` 직접 호출**: Claude Code의 plugin-namespaced skill slash command 패턴 (me plugin 다른 skill들과 동일)

### 동작 예시

```
User: /me:autoresearch "optimize parser perf, R² > 0.85"
  또는
User: "parser 성능을 R² 0.85까지 끌어올리는 실험 루프 돌려줘"

Claude (autoresearch skill 활성화):
1. 질문/추론으로 setup 완료
2. autoresearch/parser-perf-2026-05-26 브랜치 생성
3. .autoresearch/ 셋업, baseline 실행 (R²=0.62)
4. /goal "parser R² ≥ 0.85 OR 100 experiments completed" 설정
5. 첫 실험 시도 → /goal이 평가 → 조건 미충족 → 다음 턴 자동 시작
6. (사용자 개입 없이 반복)
7. R² 0.85 달성 → /goal 자동 종료 → 최종 보고
```

## 호환성 / 마이그레이션

- 기존 `.autoresearch/` 디렉토리는 그대로 호환 (포맷 변경 없음)
- 이전에 `/autoresearch off` 쓰던 사용자 → `/goal clear` 안내
- plugin 자체 이동이므로, 사용자는 marketplace에서 autoresearch plugin을 disable하고 me plugin만 사용

## 리스크

| 리스크 | 완화 |
|--------|------|
| Claude Code < v2.1.139 환경 | SKILL.md의 Prerequisites 섹션에 명시. 부재 시 에러 메시지로 안내 |
| trust dialog 미수락 워크스페이스 | /goal 자체가 안내 메시지 출력 (Claude Code 동작) |
| `disableAllHooks` / `allowManagedHooksOnly` | 동일 — /goal이 안내 |
| /goal 평가가 metric 개선을 놓치는 경우 | 조건을 명확한 측정값으로 작성 (SKILL.md에 가이드) |
| Upstream과의 divergence | 의도된 것 — 본 작업은 upstream 추종을 포기하고 우리 워크플로우 통합을 우선 |

## 성공 기준

- `plugins/autoresearch/` 디렉토리 제거되어도 `/autoresearch <goal>`이 me plugin을 통해 작동
- SKILL.md가 200줄 이하 (현재 254줄)
- hook 없이도 매 턴 자동 진행 (사용자 입력 불필요)
- 기존 `.autoresearch/` 작업물과 호환 (resume 가능)
- bats 테스트 통과 (plugin 구조 검증)

## 참고 자료

- [/goal command docs](https://code.claude.com/docs/en/goal) — Claude Code v2.1.139+
- [Claude Code Hooks Reference](https://code.claude.com/docs/en/hooks)
- [obra/autoresearch-claude-code](https://github.com/obra/autoresearch-claude-code) — upstream (마지막 변경 2026-03-18)
