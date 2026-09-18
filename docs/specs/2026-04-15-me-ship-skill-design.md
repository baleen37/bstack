# me /ship Skill Design

**Date:** 2026-04-15
**Scope:** `plugins/me/skills/ship/`
**Reference model:** `addyosmani/agent-skills`의 `/ship` 및 `shipping-and-launch`

## Goal

`me` plugin에 `/ship` 스킬을 추가한다. 이 스킬은 배포 실행기가 아니라 **출시 readiness gate**로 동작해야 한다.

`/ship`의 목적은 다음 세 가지다.

1. 현재 변경사항이 ship 가능한지 판정한다.
2. ship을 막는 누락 게이트와 위험 신호를 식별한다.
3. rollout / rollback / monitoring 준비 상태를 구조화해서 보고한다.

## Non-Goals

`/ship`은 다음을 하지 않는다.

- 프로젝트별 deploy 명령을 추측해서 실행하지 않는다.
- QA 자체를 대체하지 않는다.
- PR 생성/머지 흐름을 대신하지 않는다.
- 릴리즈 자동화나 버전 관리 전체를 떠맡지 않는다.
- 환경별 배포 orchestration 도구로 확장하지 않는다.

즉 첫 버전 `/ship`은 **배포 자동화 도구가 아니라 readiness reviewer skill**이다.

## Relationship to Existing Skills

- `/qa` = 결함 탐색, evidence 수집, QA report 작성
- `/create-pr` = PR 생성과 병합 준비 자동화
- `/ship` = 출시 readiness gate

역할을 분리해서 중복을 줄인다.

## Design Principles

`/ship`은 가능한 한 agent-skills의 `/ship` 철학을 그대로 따른다.

1. **Deploy보다 readiness 우선**
   - 배포를 직접 실행하는 것보다, 지금 내보내도 되는 상태인지 판단하는 데 집중한다.
2. **Project-specific 추측 금지**
   - 저장소에 명시되지 않은 deploy 절차나 인프라 명령을 상상해서 실행하지 않는다.
3. **Gate-first output**
   - 결과는 판정, blocker, warning, next actions 중심으로 구성한다.
4. **불확실하면 통과시키지 않음**
   - 테스트 근거, rollback 경로, monitoring 신호가 불명확하면 ready로 판정하지 않는다.

## Candidate Under Review

첫 버전 `/ship`은 **현재 작업 변경분**을 shipping candidate로 본다.

실무적으로는 아래 정보를 사용해 범위를 파악한다.

- 현재 브랜치
- 가능하면 `main...HEAD` diff
- 현재 저장소 상태와 최근 검증 흔적

단, 스킬의 핵심은 입력 파라미터 다양화가 아니라 readiness review 자체이므로, 첫 버전은 입력 모델을 단순하게 유지한다.

## Output Contract

`/ship` 결과는 아래 형식을 따른다.

### 1. Decision

세 가지 중 하나로 판정한다.

- **Ready** — ship 가능
- **Conditionally ready** — ship 가능하지만 선행 확인/승인이 더 필요
- **Not ready** — 현재 상태로는 ship 불가

### 2. Blocking issues

ship을 막는 항목을 나열한다.

예:
- 테스트 근거 없음
- rollback 경로 불명확
- 관련 QA가 필요한데 수행 근거 없음
- 배포 후 관찰 포인트 부재

### 3. Warnings

즉시 막지는 않지만 위험도가 있는 항목을 나열한다.

예:
- 큰 변경인데 staged rollout 전략 없음
- feature flag 없이 바로 노출되는 변경
- 영향 범위 설명이 모호함

### 4. Readiness by area

아래 4개 축을 각각 점검한다.

- **Pre-launch**
- **Rollout**
- **Rollback**
- **Monitoring**

### 5. Next actions

ship 전에 해야 할 최소 행동만 제시한다.

예:
- `/qa` 실행
- smoke test 결과 첨부
- rollback note 정리
- 모니터링 지표 확인 포인트 명시

## Readiness Areas

### Pre-launch checks

기본 품질 게이트가 통과됐는지 본다.

확인 예시:
- 변경 범위를 식별할 수 있는가
- 관련 테스트/검증 근거가 있는가
- 리뷰 또는 동등한 확인이 있었는가
- ship 전에 확인해야 할 문서/메모가 있는가

### Release scope clarity

이번 ship의 범위가 명확한지 본다.

확인 예시:
- 무엇을 내보내는지 한두 문장으로 설명 가능한가
- 너무 큰 변경이라 분리가 필요한가
- 직접 노출 시 위험한 변경인데 안전장치가 없는가

이 축의 결과는 blocker 또는 warning의 근거로 반영한다.

### Rollout readiness

점진 배포 관점의 안전장치를 본다.

확인 예시:
- staged rollout 개념을 적용할 수 있는가
- feature flag / kill switch / configuration gate가 있는가
- 전면 배포만 가능한 고위험 구조는 아닌가

### Rollback readiness

문제 발생 시 되돌릴 수 있는지 본다.

확인 예시:
- rollback 경로를 설명할 수 있는가
- 되돌리기 어려운 schema/data migration이 포함되는가
- 장애 시 first action이 무엇인지 명확한가

### Monitoring readiness

배포 후 관찰 가능한 상태인지 본다.

확인 예시:
- 배포 후 볼 로그/메트릭/알람이 있는가
- 성공 신호와 실패 신호가 구분되는가
- post-launch 확인 포인트가 전혀 비어 있지 않은가

## Failure Policy

`/ship`은 억지로 통과시키지 않는다.

권장 판정 규칙:

- **Not ready**
  - 테스트 근거 없음
  - rollback 경로가 전혀 설명되지 않음
  - monitoring 신호가 전혀 없음
  - ship 전에 반드시 필요한 선행 QA/검토가 누락됨
- **Conditionally ready**
  - 핵심은 통과했지만 rollout 또는 monitoring 계획이 약함
  - 위험도는 낮지만 사람이 마지막 확인을 해야 함
- **Ready**
  - blocker 없음
  - rollout / rollback / monitoring 관점에서 기본 설명 가능

## File Structure

첫 버전은 최소 구조로 시작한다.

```text
plugins/me/skills/ship/
├── SKILL.md
└── references/
    └── ship-checklist.md
```

### `SKILL.md`

항상 로드되는 핵심 문서.

포함 내용:
- trigger 문구
- `/ship`의 역할과 비목표
- readiness review 단계
- output contract
- red flags
- verification expectations

### `references/ship-checklist.md`

필요 시 읽는 보조 문서.

포함 내용:
- pre-launch / rollout / rollback / monitoring 체크 예시
- blocker vs warning 판단 예시
- ship 판정 문구 예시

## Suggested SKILL Flow

1. 현재 변경 범위와 ship candidate를 파악한다.
2. pre-launch 관점에서 기본 검증 근거를 확인한다.
3. rollout / rollback / monitoring 준비 상태를 점검한다.
4. blocker와 warning을 분리한다.
5. Ready / Conditionally ready / Not ready 중 하나로 판정한다.
6. next actions를 최소 단위로 정리한다.

## Testing Strategy

이 스킬은 배포 자동화보다 **결정 규칙과 출력 구조**가 중요하므로 테스트도 그 관점으로 잡는다.

### Static validation

- skill frontmatter가 유효한지
- 필수 섹션이 존재하는지
- reference 경로가 맞는지

### Behavior validation

- `/ship`이 deploy 실행 지시로 기울지 않는지
- blocker / warning / next actions를 분리하는지
- `/qa`, `/create-pr` 역할과 섞이지 않는지

### Regression validation

- 자동 병합이나 배포 실행처럼 범위를 넘는 지시가 없는지
- readiness reviewer라는 경계를 유지하는지

## Acceptance Criteria

다음이 만족되면 설계 목표를 달성한 것으로 본다.

- `plugins/me/skills/ship/SKILL.md`가 존재한다.
- `/ship`이 readiness gate로 정의되어 있다.
- deploy 명령 실행이 기본 흐름에 포함되지 않는다.
- 결과 형식에 Decision / Blocking issues / Warnings / Readiness areas / Next actions가 포함된다.
- `/qa`와 `/create-pr`와의 역할 경계가 문서에 명시된다.
- rollout / rollback / monitoring 관점이 빠지지 않는다.

## Open Questions Resolved

- `/ship`은 배포 실행기인가? → 아니다. readiness gate다.
- `/qa`를 흡수하는가? → 아니다. 독립 유지한다.
- agent-skills를 얼마나 따를 것인가? → 가능한 한 그대로 따른다.
- 첫 버전에서 다양한 입력 모델을 지원하는가? → 아니다. 현재 변경분 중심으로 단순하게 간다.

## Implementation Direction

다음 단계에서는 이 설계를 바탕으로 `SKILL.md` 초안과 reference 문서 구조를 계획하면 된다. 첫 구현은 최소 기능으로 시작하고, 실제 사용 사례가 쌓이면 PR 입력, 환경별 컨텍스트, 프로젝트별 신호 소스 연결 같은 확장을 검토한다.
