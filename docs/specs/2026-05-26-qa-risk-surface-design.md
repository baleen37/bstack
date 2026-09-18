# /qa Risk Surface 개선

## 배경

`/qa` 스킬이 변경의 실질 위험이 외부 시스템 경계(OpenSearch, DB, 외부 API 등)에 있을 때조차 단위 테스트 + 빌드 + 린트로 검증을 끝내는 회피 패턴이 관찰되었다. 특히 계획서/Rollout 메모에 "배포 전 ~ 확인 권장" 같은 항목이 명시되어 있어도 "exhaustive QA가 아니다"라는 핑계로 사용자에게 검증 책임을 떠넘기는 사례가 발생.

## 근본 원인 (합의된 진단)

복합 원인:
1. **스킬 정의의 모호함**: "Default to change-centered verification, not exhaustive QA" 문구가 외부 경계 검증을 빠뜨릴 여지를 제공
2. **위험 평가 단계 부재**: 검증 시작 전에 "변경의 실질 위험이 어디에 있는가"를 식별하는 단계 없음
3. **계획서 연계 누락**: plan/Rollout 메모의 "확인 권장" 항목이 자동으로 검증 범위에 포함되지 않음

## 합의된 원칙

- 위험이 외부 경계에 있으면 **항상 직접 확인**한다 (접근 가능한 한)
- 검증 전에 **명시적 Phase 0**에서 Risk Surface를 식별한다
- 접근 불가능한 경우(SSO 만료, 권한 없음 등) **사용자에게 알리고 합의**한 뒤 진행한다
- 계획서의 "확인 권장" 항목은 **자동으로 검증 범위에 포함**한다
- PASS는 **모든 식별된 Risk Surface가 검증되었을 때**만 부여한다

## 접근법

**A안 (선택됨): Phase 0 추가형**

기존 흐름을 유지하면서 Phase 1(Scope) 앞에 Phase 0(Risk Surface)를 추가하고, PASS 정의를 조이고, 회피 어구를 제거하는 최소 변경.

대안으로 검토했지만 채택하지 않은 안:
- B (게이트 중심 재구조화): 단순 변경에도 게이트가 걸려 마찰이 큼
- C (Risk-driven 분기형): 분기 결정 자체가 새 회피 포인트가 됨

## 변경 사항

### 1. `plugins/me/skills/qa/SKILL.md`

#### `## What /qa verifies` 섹션

- 회피 어구 "Default to change-centered verification, not exhaustive QA" 삭제
- verification set에 "all Risk Surfaces identified in Phase 0" 추가

수정 후:

```markdown
## What /qa verifies

Focus on the current work context:

- the intended golden path
- the most relevant edge cases
- obvious regressions near the changed behavior
- all Risk Surfaces identified in Phase 0 (외부 시스템 경계는 항상 직접 검증)

`/qa` is the default verification path. If cross-service or multi-layer flow integrity is the main risk, add `/e2e`.
```

#### `## Verification flow` 섹션에 Phase 0 추가

Phase 1(Scope) 앞에 다음 추가:

```markdown
### Phase 0: Risk Surface

변경된 코드가 외부 시스템 경계(OpenSearch, DB, message queue, 외부 API, 파일 시스템 등)와 상호작용하는지 식별한다.

식별 단서:
- diff에 외부 클라이언트/리포지토리/게이트웨이 호출이 포함됨
- 계획서나 Rollout 메모에 "배포 전 ~ 확인 권장" 같은 항목이 있음

각 Risk Surface에 대해 다음을 결정한다:
1. 어떤 호출/조회로 검증할 것인가
2. 지금 접근 가능한가 (SSO, 권한, 터널 등)

접근 불가능한 Risk Surface가 있으면 검증을 시작하기 전에 사용자에게 알리고, 접근 방법을 제공받거나 그 항목을 제외해도 되는지 명시적으로 확인받는다. 사용자 확인 없이 건너뛰지 않는다.
```

#### `## Verdicts` 섹션 조임

수정 후:

```markdown
- **PASS** — Phase 0에서 식별된 모든 Risk Surface와 시나리오가 검증되었고, 문제가 없음
- **PARTIAL** — 검증되지 않은 Risk Surface가 있거나, 일부 시나리오가 실패/불완전/불확실
- **FAIL** — 핵심 시나리오가 실패했거나 의도한 동작과 명백히 다름
```

### 2. `plugins/me/skills/qa/templates/qa-report-template.md`

`## Scope` 섹션 바로 뒤에 다음 추가:

```markdown
## Risk Surface

- {외부 시스템 경계} — verified / skipped (reason) / inaccessible
```

### 3. 손대지 않는 파일

- `references/exploration-guide.md`, `references/issue-taxonomy.md`: Phase 1/2의 보조 자료로 그대로 유지
- 신규 reference 파일 추가 없음 (단순화 결정)

## 성공 기준

- "default to change-centered verification" 회피 어구가 제거됨
- Phase 0이 SKILL.md에 명시되어 있음
- PASS 정의가 "모든 Risk Surface 검증" 조건을 포함함
- 템플릿에 Risk Surface 섹션이 있음
- 다음 /qa 실행 시 LLM이 Phase 0에서 외부 경계를 명시적으로 식별하고, 접근 불가 시 사용자에게 합의를 요청함

## 비범위

- /e2e, /ship 스킬 변경 없음
- references 파일 신규 생성 없음
- /qa의 verdict 분기 후 transition 흐름은 그대로
