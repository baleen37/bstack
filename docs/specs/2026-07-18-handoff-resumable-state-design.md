# Handoff Resumable State Redesign

## Purpose

`handoff`를 세션 회고문이 아니라 다음 세션이 상태를 검증하고 즉시 작업을
재개할 수 있는 간결한 상태 인계서로 만든다.

## Success Criteria

- 출력만 읽어도 완료한 일, 현재 상태, 다음 작업을 구분할 수 있다.
- 다음 세션의 첫 행동과 검증 방법이 명시된다.
- 전체 대화나 명령 로그를 복제하지 않는다.
- 일반 개발 세션에는 최소 구조만 사용하고, 추가 맥락은 실제 내용이 있을
  때만 기록한다.
- 기존 저장 경로 변경과 `pickup` 제거 작업을 보존한다.

## Output Model

### Required core

1. `Task`
   - Goal
   - Scope
   - Done when
2. `Completed`
   - 이번 세션에서 실제로 끝낸 작업
3. `Current State`
   - 진행 중인 지점
   - worktree, branch, commit
   - 마지막 검증 명령과 결과
4. `Next Steps`
   - 첫 행동을 명시
   - 중요한 단계는 검증 방법 또는 완료 조건과 결합
5. `Blockers & Open Questions`
   - 확인되지 않은 사실, 사용자 결정 대기, 외부 blocker
6. `Context`
   - 중요 파일, PR, 이슈, 문서, 실행 결과의 안정적인 포인터

내용이 없는 `Blockers & Open Questions`와 `Context`는 생략할 수 있다.

### Conditional context

실제 재개 오류를 막는 경우에만 다음 항목을 추가한다.

- Design Decisions: 결정과 이유
- Failed Approaches: 시도, 정확한 실패 결과, 반복하면 안 되는 이유
- Gotchas: 다음 세션이 지켜야 할 일시적인 제약
- Explicit User Instruction: handoff 호출 시 사용자가 지정한 다음 행동

영구적인 사용자 선호나 저장소 규칙은 handoff에 복제하지 않는다. 해당 규칙이
이미 `AGENTS.md`, `CLAUDE.md` 또는 다른 지속 문서에 있다면 경로만 참조한다.

## Resume Protocol

`Resume Prompt`와 `Resume Checkpoint`를 별도 중복 섹션으로 유지하지 않는다.
대신 `Current State`와 `Next Steps`가 다음 재개 절차를 직접 표현한다.

1. 기록된 worktree, branch, commit이 현재 환경과 일치하는지 확인한다.
2. `Last verified` 명령을 다시 실행하거나 상태가 바뀌었는지 확인한다.
3. 불일치하면 추정해서 진행하지 않고 차이를 먼저 보고한다.
4. `Next Steps`의 첫 행동부터 시작한다.

## Content Rules

- 시간순 활동 로그보다 현재 상태를 먼저 이해할 수 있게 쓴다.
- 완료, 진행 중, 미착수를 섞지 않는다.
- 확인된 사실과 가설을 구분한다.
- 경로, commit, PR, issue, 명령처럼 다시 확인 가능한 포인터를 우선한다.
- 비밀, 전체 로그, stack trace, 대화 덤프는 기록하지 않는다.
- `TODO`, `N/A`, `...` 같은 placeholder나 빈 섹션을 남기지 않는다.

## Validation

스킬 수정 전 기존 스킬로 대표 handoff 시나리오를 실행하여 다음 실패를 확인한다.

- 완료한 작업이 `Current state`에 섞이는지
- `Resume Prompt`, `Next Steps`, `Resume Checkpoint`가 중복되는지
- 다음 세션의 첫 행동이 하나로 결정되는지

수정 후 동일 시나리오에서 다음을 검증한다.

- core 필드가 의미상 중복 없이 채워진다.
- 첫 행동과 재검증 명령이 명확하다.
- 내용 없는 conditional section은 생략된다.
- 기존 XDG 저장 경로와 write-only 동작은 유지된다.

## Out of Scope

- handoff 자동 선택 또는 읽기
- 세션 자동 재개
- `pickup` 복원
- incident 전용 역할, severity, 고객 공지, 전체 timeline
- project-local handoff 저장
