# me:handoff skill — Design

## Purpose

현재 Claude 세션의 컨텍스트를 다음 세션이 이어받을 수 있도록 구조화된 마크다운 파일로 남긴다. 사용자가 명시적으로 호출할 때만 작동.

## Scope

- **In scope**: 현재 세션 컨텍스트를 타임스탬프 파일로 저장
- **Out of scope**: resume 로직, 자동 트리거, 세션 요약 압축, 다른 도구 통합

받는 쪽은 사용자가 파일 경로를 새 세션에 붙여넣거나 내용을 복붙하면 Claude가 프론트매터와 재개 프롬프트를 보고 알아서 맥락 파악.

## Location

- Skill: `plugins/me/skills/handoff/SKILL.md`
- Output: `~/.claude/handoff/YYYY-MM-DD-HHmm-<topic>.md`
  - `<topic>`: 현재 작업 내용에서 2-4단어 kebab-case 요약을 Claude가 생성
  - 디렉토리 없으면 생성
  - 로컬 시간 (타임존 의존 없이 사용자가 파일명 보고 바로 알아볼 수 있도록)

## Trigger

사용자 명시 호출만:
- `/me:handoff`
- "handoff 만들어줘", "인수인계 파일 만들어줘"
- "다음 세션용으로 정리해줘"

자동 트리거 없음. SessionEnd hook 등은 이 스킬의 범위 밖.

## Flow

1. 환경 스냅샷 수집 (병렬):
   - `git status --short`
   - `git diff --stat`
   - `git log -5 --oneline`
   - `git branch --show-current`
   - `pwd`
2. 현재 대화에서 추출:
   - 작업 목표 / 현재 상태
   - 다음 할 일
   - Open Questions (결정 대기, 막힌 지점)
   - Design Decisions (결정 + 이유)
   - Failed Approaches (시도했으나 실패한 접근)
   - User Preferences (이번 세션에서 배운 주의점)
3. 토픽 추정 → 파일명 생성 → `~/.claude/handoff/` 생성 후 파일 쓰기
4. 사용자에게 파일 경로 출력

## Output Template

```markdown
---
date: 2026-04-22 14:30
worktree: /path/to/worktree
branch: feature/xyz
commit: abc1234
topic: <kebab-case>
---

# Handoff: <짧은 한 줄 제목>

## 재개 프롬프트
> 다음 세션에 그대로 붙여넣을 한 문단. "X 작업 중이었고 Y까지 함. 이제 Z부터 이어서 해줘."

## Goal & Current State
- 목표: ...
- 현재 상태: ...

## Next Steps
1. ...
2. ...

## Open Questions
- ... (결정 대기/막힌 지점)

## Design Decisions
- 결정: ... — 이유: ...

## Failed Approaches
- 시도: ... — 실패 이유: ...

## Recent Changes
- 수정 파일: `path/a.ts`, `path/b.ts`
- 커밋: `abc1234 feat: ...`
- 미커밋 변경: <git status 요약>

## Environment
- Worktree: `/path`
- Branch: `feature/xyz`
- PR/이슈: #123

## User Preferences
- ...
```

섹션별 내용이 없으면 섹션을 빈 채로 두지 말고 생략한다.

## Anti-Patterns to Avoid

- ❌ 전체 대화 덤프 — 노이즈만 늘어남
- ❌ 추측성 "possible next steps" — 실제 논의/결정된 것만
- ❌ 산문 위주 서술 — bullet 중심, 간결하게
- ❌ 자동 트리거 / SessionEnd 통합 — 범위 밖
- ❌ 비어있는 섹션 채우기 — 해당 없으면 생략

## Non-Goals

- resume 로직 없음. 사용자가 파일을 새 세션에 붙여넣으면 Claude가 자연어로 해석.
- 프로젝트 로컬 저장 없음. `~/.claude/handoff/` 전역만.
- git 통합 없음. 출력물은 git 추적 대상 아님.
