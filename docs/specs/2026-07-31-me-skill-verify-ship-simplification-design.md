# me 플러그인 검증/배포 스킬 단순화

**날짜:** 2026-07-31
**대상:** `plugins/me/skills/{qa,e2e-scenario-testing,story-loop,ship}`

## 배경

`plugins/me/skills/`의 검증 계열 3개와 배포 계열 1개가 서로 경계가 흐릿하고,
지난 정리(PR#725)에서 삭제된 스킬을 여전히 참조하고 있다.

실사용 집계 (`~/.claude/projects`의 `.jsonl`에서 Skill tool `input.skill` 값 기준):

| 스킬 | invoke | 줄 수 |
| --- | --- | --- |
| `ship` | 4 | 203 |
| `qa` | 1 | 144 |
| `e2e-scenario-testing` | 0 | 142 |
| `story-loop` | 0 | 189 |

0회짜리 2개는 삭제 후보였으나, 사용자가 두 스킬의 설계 가치를 유지하기로
결정했다. 문제는 존재 이유가 아니라 이름과 경계다.

### 이름이 축을 섞어 쓰는 문제

| 스킬 | 이름이 말하는 것 | 축 |
| --- | --- | --- |
| `qa` | 누가 하는가 | 역할 |
| `e2e-scenario-testing` | 어디까지, 어떻게 | 범위 + 방법 |
| `story-loop` | 무엇을 반복하는가 | 산출물 + 제어 흐름 |

축이 셋 다 달라서 이름만 보고 언제 뭘 부를지 판단할 수 없다.

### 깨진 참조

- `qa/SKILL.md` — `/e2e` 3곳 참조. 해당 스킬은 삭제됨, `e2e-scenario-testing`이 후속.
- `qa/references/exploration-guide.md:18` — `/browse` 참조. 존재하지 않음.
- `ship/SKILL.md:128` — `me:browse`, `me:verify` 참조. 둘 다 존재하지 않음.
- `ship/SKILL.md:148,177` — `references/{security,performance,accessibility}-checklist.md`
  3개 인용. `ship/references/` 디렉터리 자체가 없음.

## 결정

### 1. `qa` → `verify` 리네이밍

`plugins/me/skills/qa/` → `plugins/me/skills/verify/`, frontmatter `name` 갱신,
`templates/qa-report-template.md` → `templates/report-template.md`.

근거:

- 스킬이 실제로 하는 일(검증하고 PASS/PARTIAL/FAIL 판정)과 이름이 일치한다.
  `qa`는 업계 통용어라 "릴리스 게이트"로 읽히는데, 이 스킬은 명시적으로
  릴리스 게이트가 아니다.
- `superpowers:verification-before-completion`과 어휘가 맞는다.
- `ship`(내보낸다)과 대비가 선명하다. `qa` vs `ship`은 둘 다 릴리스 냄새가 난다.
- 슬래시 호출 로그에 `/verify` 1건이 있고 `/e2e`는 0건이다.

`description`의 트리거 문구에 `qa`는 남긴다. 이름은 바꾸되 입구는 좁히지 않는다.

`e2e-scenario-testing`과 `story-loop`은 이름을 유지한다. 손에 익은 이름을
지키는 쪽을 택했다.

### 2. 용어 통일

같은 개념이 스킬마다 다른 단어로 불린다. 아래로 고정한다.

| 개념 | 통일 용어 | 정리 대상 표현 |
| --- | --- | --- |
| 검증 대상 한 건 | `scenario` | card, story, capability, check |
| 그 파일 | `scenario card` | card, `.md` file |
| 실패 조건 명시 | `falsification condition` | "if you see X instead" |
| 판정 | `verdict` (PASS/PARTIAL/FAIL) | result, 판정 |
| 외부 시스템 접점 | `risk surface` | 외부 시스템 경계, external boundary |
| 증거 | `evidence` | 증거, capture |

`story-loop`이 `story` / `scenario` / `capability`를 섞어 쓰는데 셋 다 같은
것을 가리킨다. `scenario`로 모은다. 스킬 이름 `story-loop`은 유지하고
본문 용어만 통일한다.

### 3. 경계 명문화

세 SKILL.md 상단에 동일한 블록을 넣는다.

```text
/verify — 변경분 하나가 의도대로 동작하나 (기본 경로)
/e2e-scenario-testing — 실행 중인 앱을 실제 인터페이스로 구동, 시나리오 1건
/story-loop — 레포 전체를 시나리오로 카탈로그화 후 통과까지 루프
```

### 4. `ship` 슬림화 (203 → ~85줄)

**유지:** Overview, Automation Policy(위임 기준 포함), 3-phase Execution
Workflow, Decision Categories, Reading Deploy Convention, Post-Deploy
Verification, Rollback.

**삭제:** Common Rationalizations 표, Red Flags, Feature Flags, Staged Rollout
표, Pre-Launch Checklist, When to Use, See Also, 말미 Verification 절.

삭제 근거: 전부 프로젝트 무관 일반론이다. 실제 배포 판단에 쓰이는 것은
Deploy Convention(프로젝트가 제공)과 Post-Deploy Verification(증거 수집)이다.
Staged Rollout 임계값 표는 프로젝트마다 다른 값이라 스킬에 하드코딩할 근거가 없다.

**깨진 참조 수정:** 존재하지 않는 references 3개 인용 제거, `me:browse` /
`me:verify` → `me:verify`(리네이밍으로 유효해짐) + 브라우저 자동화는
`claude-in-chrome`.

### 5. SkillOpt-Sleep 후속

슬림화된 `ship`을 시드로 SkillOpt-Sleep을 돌려 실제 배포 세션에서 드러난
결함을 보완한다.

**역할 분담:** 삭제는 사람이, 보완은 SkillOpt이 한다. SkillOpt의 편집 모델은
held-out scorer를 올리는 add/replace 편집이라 "이 절은 일반론이니 잘라라"라는
판단을 못 한다. `--edit-budget`은 편집 횟수를 제한할 뿐 최종 길이를 제한하지
않는다. 따라서 슬림화 자체는 Sleep으로 할 수 없다.

**스코프 주의:** `ship` invoke 4건은 전부 `search` / `search-data` 프로젝트
세션에 있고, 스킬 파일은 `bstack`에 있다. `--project`(마이닝 대상 히스토리)와
`--target-skill-path`(진화 대상 파일)는 독립 플래그이므로 분리해서 지정한다.

**backend:** `handoff`. 현재 세션이 모델 호출을 직접 답한다. 사내 search 인프라
세션 발췌가 provider로 나가지 않고, 별도 API 키가 필요 없다. held-out gate
오염을 막기 위해 각 프롬프트는 fresh context subagent에서 답한다.

**런너:** `~/dev/SkillOpt` (upstream `microsoft/SkillOpt`, commit `8304e6c`,
2026-07-28). `python -m skillopt_sleep`. 제안은 staged 상태로 두고 `adopt`는
사용자가 확인한 뒤 별도로 실행한다.

## 테스트

`tests/me/me-specific.bats:42`가 `ship/SKILL.md` 존재를 확인한다. 경로가
바뀌지 않으므로 통과한다. `qa` 경로를 확인하는 테스트는 없다.

SKILL.md 내용/frontmatter를 검증하는 테스트는 새로 만들지 않는다
(CLAUDE.md 지침).

`plugins/me/README.md`의 스킬 목록을 갱신한다.

## 검증 기준

1. `plugins/me/skills/verify/SKILL.md` 존재, `qa/` 디렉터리 없음
2. 저장소 전체에서 `/e2e`, `/browse`, `me:browse` 참조 0건
3. `ship/SKILL.md` 약 85줄, 존재하지 않는 파일 인용 0건
4. `bats tests/` 통과
5. `pre-commit run --all-files` 통과
