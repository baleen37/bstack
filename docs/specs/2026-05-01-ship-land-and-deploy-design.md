# Ship + Land-and-Deploy Design (gstack 채택)

- 날짜: 2026-05-01
- 상태: 채택
- 출처: <https://github.com/garrytan/gstack> — `ship/SKILL.md`, `land-and-deploy/SKILL.md`

## 배경

기존 `/ship`은 단일 스킬로 readiness 평가 + PR 머지 + 배포 모니터링까지 모두 책임지려 했고, 단계마다 confirm 왕복이 누적되어 사용자 가시성과 idempotency가 모두 떨어졌다.

revert 히스토리:

- PR #635: `/ship`을 launch task runner 구조로 재작업. 자체 PLAN preview만으로 readiness를 판단하려 했고, default task set이 web/API 편향이라 라이브러리/CLI/플러그인 변경에는 과잉 게이팅이 발생. EXECUTE 단계에서 per-task confirm 왕복이 불투명해 사용자가 진행 상황을 추적하기 어려웠다.
- PR #637: launch task runner를 되돌리고 readiness reviewer를 복구. 이번 변경은 그 위에 gstack 구조를 얹는 방향.

## 결정

gstack의 2-스킬 분리 구조를 채택한다.

- `/ship` — PR 머지 직전까지 readiness 게이트
- `/land-and-deploy` — PR 머지부터 배포 검증까지

**A2 위임 구조**: gstack 본문/원칙은 보존하고, gstack이 자체 수행하던 부분(테스트 실행, PR 생성, 머지 대기, CI 실패 복구, 버전/체인지로그)만 우리 레포의 기존 스킬로 위임한다.

## 책임 경계

| 단계 | /ship | /land-and-deploy |
| --- | --- | --- |
| Readiness 평가 (스코프 드리프트, 신뢰도) | O | - |
| 자체 테스트 / 통합 테스트 | O (위임) | - |
| PR 생성 / push | O (위임) | - |
| **PR 머지** | - | O (위임) |
| 배포 모니터링 / 헬스체크 | - | O |
| Migration 단계 | - | O (gstack 원본) |
| Revert escape hatch | O | O |

경계: **PR 머지 시점**. 머지 직전까지 `/ship`, 머지 호출부터 `/land-and-deploy`.

## gstack 핵심 원칙 (보존)

- **Boil the Lake** — 한 번 실행으로 가능한 모든 게이트를 돌린다.
- **Idempotent re-run** — 동일 상태에서 재실행 시 부작용 없음.
- **Non-blocking by default** — 차단은 명시적 신호가 있을 때만.
- **Confidence Calibration** — 신뢰도를 명시적으로 추정하고 게이트 강도를 조정.
- **Adaptive Gating** — 변경 종류(라이브러리/웹/CLI/플러그인)에 따라 게이트 셋을 동적으로.
- **Scope Drift Detection** — 의도 외 파일 변경을 적극적으로 surfacing.
- **Revert as escape hatch** — 막히면 항상 revert가 first-class option.

## 위임 매핑

| gstack 자체 수행 | 우리 위임 대상 |
| --- | --- |
| 자체 테스트 | `/qa` |
| E2E | `/e2e` |
| PR 생성 / push | `/create-pr` |
| 머지 대기 | `/create-pr`의 `wait-for-merge.sh` |
| CI 실패 복구 | `/pr-pass` |
| VERSION / CHANGELOG | semantic-release |

## 진행 단계 추적

`TaskCreate`로 단계를 등록한다.

- **채택 사유**: idempotent (재실행 시 기존 task 재활용 가능) + 사용자 가시성 (TaskList로 한눈에 확인).
- **금지**: per-task confirm 왕복. PR #635에서 확인된 함정. 기본은 non-blocking, 차단 신호가 명시적일 때만 멈춘다.

## Migration

gstack 원본 그대로 따른다. `/land-and-deploy`에 단계를 추가하지 않는다. schema/data 안전성 평가는 머지 전 단계인 `/ship`에서 처리한다 (스코프 드리프트 + 신뢰도 추정으로 흡수).

## 알려진 이슈

- 새 SKILL.md 들이 markdownlint 위반을 포함. 레포 전체 패턴과 동일한 종류 (line length, list spacing). 별도 PR로 일괄 정리 권장.

## 출처

- <https://github.com/garrytan/gstack> `ship/SKILL.md`
- <https://github.com/garrytan/gstack> `land-and-deploy/SKILL.md>
