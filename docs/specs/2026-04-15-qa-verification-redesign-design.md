# QA Verification Redesign Spec

**Date:** 2026-04-15
**Scope:** `plugins/me/skills/qa/`
**Related context:** `/ship` is now a shipping readiness gate; `/qa` remains independent.

## Goal

`/qa`를 버그 탐색 중심 스킬에서 **기능 구현 검증 중심 스킬**로 재정렬한다.

핵심 질문은 더 이상 “무슨 버그를 많이 찾을까?”가 아니라, 아래가 된다.

- 이 기능이 의도대로 동작하는가?
- 이번 구현 변경이 검증 기준을 통과하는가?
- `/ship` 전에 기능 검증 근거가 충분한가?

## Role Redefinition

### `/qa`의 새 역할

`/qa`는 현재 작업 문맥에 대해 **implementation verification**를 수행한다.

기본 검증 범위:
- golden path
- 핵심 edge case
- 명백한 regression

기본 출력:
- **PASS**
- **PARTIAL**
- **FAIL**

### `/qa`가 하지 않는 일

- 기본 목표를 exploratory bug hunting으로 두지 않는다.
- 출시 readiness 판단을 대신하지 않는다.
- rollout / rollback / monitoring readiness를 판단하지 않는다.
- 구현 수정까지 직접 수행하지 않는다.

## Boundary with `/ship`

역할 분리는 명확해야 한다.

- `/qa` = **이 기능/변경이 제대로 동작하는가**
- `/ship` = **이 변경을 지금 내보내도 되는가**

`/ship`은 readiness gate이고, `/qa`는 기능 검증 결과를 제공하는 하위 근거가 된다.

예를 들어:
- `/qa = PASS` → `/ship`이 기능 검증 근거를 활용할 수 있음
- `/qa = PARTIAL` → `/ship`은 조건부 readiness로 기울 수 있음
- `/qa = FAIL` → `/ship`은 blocker로 취급 가능

## Scope Resolution Rules

`/qa`는 고정 입력 하나만 보는 스킬이 아니라, **현재 작업 문맥을 해석해서 검증 범위를 정하는 스킬**이다.

### 기본 우선순위

명시적 override가 없을 때:

1. **plan**
2. **branch**
3. **user hint** — plan 또는 branch 기반 범위를 보정하는 추가 힌트일 뿐, 별도 scope source는 아니다.

### 예외 규칙

사용자가 명시적으로 범위를 override하면 그 요청을 최우선으로 따른다.

예:
- “로그인만 봐줘”
- “search API만 검증해줘”
- “checkout 성공 플로우만 확인해줘”

이 경우 `/qa`는 이를 **user override**로 취급한다.

### Scope source 표기

리포트 상단에는 scope가 어디서 왔는지 드러낸다.

- `Scope source: plan`
- `Scope source: branch`
- `Scope source: user override`

이 표기는 왜 그 범위를 검증했는지 설명하는 메타데이터 역할을 한다.

## Verification Model

기본 `/qa`는 exhaustive QA가 아니다.

기본값은 **변경 중심 기능 검증**이다.

### 기본 검증 세트

1. **Golden path**
   - 가장 중요한 정상 흐름이 끝까지 동작하는지 확인한다.

2. **핵심 edge case**
   - 해당 기능에서 대표적인 경계 조건이 처리되는지 확인한다.

3. **명백한 regression**
   - 이번 변경 때문에 인접 기능이 바로 깨지지 않았는지 확인한다.

### 확장 모드

사용자가 원하면 더 넓은 QA로 확장할 수 있다.

예:
- “좀 더 넓게 봐줘”
- “release QA처럼 해줘”
- “regression 넓게 확인해줘”

하지만 기본 `/qa`는 항상 가볍고 목적 중심이어야 한다.

## Output Contract

`/qa` 결과는 **검증 판정 중심**으로 구성한다.

### 1. Verdict

항상 최상단에 하나의 판정을 낸다.

- **PASS** — 핵심 기능 검증이 통과했고, 현재 scope 안에서 막을 만한 구현 문제가 보이지 않음
- **PARTIAL** — 주요 기능은 대체로 되지만, 실패/미검증/불확실성이 남음
- **FAIL** — 핵심 시나리오 검증에 실패했거나 구현이 의도대로 동작하지 않음

### 2. Scope

리포트에는 아래를 포함한다.

- 검증 대상 기능/시나리오
- `Scope source: plan | branch | user override`

### 3. Verification summary

다음을 요약한다.

- golden path 결과
- 핵심 edge case 결과
- 명백한 regression 확인 결과

### 4. Failed / incomplete scenarios

실패하거나 아직 충분히 검증되지 않은 시나리오를 나열한다.

### 5. Evidence

근거를 첨부한다.

예:
- 실행 로그
- 스크린샷
- HTTP 응답
- 재현 절차

### 6. Issues

문제가 있을 경우 taxonomy를 보조 분류 체계로 사용한다.

중요한 점은, **Issues는 주 출력이 아니라 Verdict를 뒷받침하는 상세 정보**라는 점이다.

### 7. Next actions

- 무엇을 수정해야 하는가
- 무엇을 다시 검증해야 하는가
- `/ship`에 넘기기 전에 어떤 검증 공백을 메워야 하는가

## File-Level Design Direction

기존 구조는 대체로 유지하되, 강조점을 바꾼다.

```text
plugins/me/skills/qa/
├── SKILL.md
├── references/
│   ├── issue-taxonomy.md
│   └── exploration-guide.md
└── templates/
    └── qa-report-template.md
```

### `SKILL.md`

중심 메시지를 바꾼다.

현재의 “find bugs / QA engineer” 톤을 줄이고, 아래를 강조해야 한다.

- implementation verification
- scope resolution
- verdict-first output
- golden path / edge case / regression
- `/ship`과의 경계

### `templates/qa-report-template.md`

현재 template는 issue report에 가까우므로 verdict-first 구조로 재배치한다.

우선순위:
1. Verdict
2. Scope
3. Verification summary
4. Failed / incomplete scenarios
5. Evidence
6. Issues
7. Next actions

### `references/issue-taxonomy.md`

유지한다. 다만 주역은 아니다.

이 taxonomy는 “무슨 종류의 문제인가”를 설명하는 보조 분류 체계로 남긴다.

### `references/exploration-guide.md`

완전히 제거하지는 않는다. 다만 “무작정 넓게 탐색하라”는 느낌보다, scope 안에서 어떤 검증 포인트를 볼지 안내하는 참고자료로 사용한다.

## Transition Behavior

현재 `/qa`는 리포트 후 수정 여부를 묻는다. 이 부분은 유지 가능하다.

다만 프롬프트 의미가 바뀐다.

기존:
- “N개 이슈를 발견했습니다. 수정하시겠습니까?”

개선 후:
- “검증 결과는 PASS/PARTIAL/FAIL입니다. 수정 후 다시 검증하시겠습니까?”

즉 중심이 issue count에서 verification verdict로 이동한다.

## Testing Strategy

새 설계에 맞춰 `/qa` 테스트도 업데이트해야 한다.

### Content-level checks

- SKILL.md가 bug-hunt보다 verification-first 언어를 사용하는지
- `PASS / PARTIAL / FAIL` verdict가 명시되는지
- scope source 개념이 들어가는지
- `/ship` readiness 역할을 침범하지 않는지

### Template checks

- qa-report-template이 verdict-first 구조인지
- Scope / Verification summary / Failed scenarios / Evidence / Next actions가 포함되는지
- issue taxonomy가 보조 섹션으로 밀려나는지

### Boundary checks

- `/qa`가 deploy / rollout / rollback / monitoring readiness를 직접 판단하지 않는지
- `/ship`과 역할 중복이 줄었는지

## Acceptance Criteria

다음이 만족되면 목표를 달성한 것으로 본다.

- `/qa`가 기능 구현 검증 중심 스킬로 정의된다.
- 기본 출력이 verdict-first (`PASS / PARTIAL / FAIL`) 구조를 가진다.
- scope 해석 규칙이 문서에 명시된다.
- 명시적 user override 규칙이 포함된다.
- 기본 검증 세트가 golden path / 핵심 edge case / 명백한 regression으로 정의된다.
- `/ship`과의 역할 경계가 문서에 명확히 적힌다.
- issue taxonomy는 유지하되 보조 역할로 재배치된다.

## Resolved Decisions

- `/qa`의 중심은 bug exploration이 아니라 implementation verification이다.
- 기본 출력은 issue list보다 verdict-first가 우선이다.
- 기본 scope는 plan → branch 문맥을 따르되, 명시적 user override는 최우선 예외로 처리한다.
- 기본 `/qa`는 exhaustive QA가 아니라 변경 중심 검증이다.
- 사용자가 원할 때만 넓은 regression / release QA로 확장한다.

## Implementation Direction

다음 단계에서는 `/qa`를 전면 재작성하기보다, 기존 lean 구조를 유지하면서 다음을 바꾸는 계획을 세우면 된다.

1. SKILL.md의 역할/톤/출력 계약 재정렬
2. qa-report-template verdict-first 재배치
3. 관련 테스트를 verification-first 기준으로 업데이트
4. 필요 시 transition 메시지를 verdict 중심으로 수정
