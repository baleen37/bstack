# Codex Skill Plugin Compatibility Design

**Date:** 2026-04-22
**Scope:** `plugins/*/skills/**`, `plugins/*/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`
**Primary constraint:** Claude Code가 메인이고, Codex는 이를 지원하는 배포 레이어로 동작해야 한다.

## Goal

기존 Claude Code 중심 플러그인 저장소에서 **동일한 skill 자산을 재사용해 Codex plugin 배포를 지원**한다.

핵심 목표는 세 가지다.

1. Claude용 skill 원본과 배포 메타데이터를 계속 정본으로 유지한다.
2. Codex용 plugin manifest와 marketplace metadata를 자동 생성한다.
3. 사람이 두 포맷을 수동으로 이중 관리하지 않도록 한다.

## Non-Goals

이번 범위는 아래를 포함하지 않는다.

- Codex용 custom agent 배포
- Claude hooks/agents를 Codex 구조로 직접 변환
- Claude 구조를 Codex 중심 구조로 뒤집는 리팩터링
- 공통 중간 스펙 파일을 새로 도입하는 추상화
- Codex 전용 skill 콘텐츠 분기

즉 이번 작업은 **skill 중심 Codex plugin 호환 레이어**만 추가한다.

## Context

현재 저장소는 Claude 중심 구조다.

- 각 플러그인은 `plugins/*/.claude-plugin/plugin.json`을 가진다.
- 루트 `.claude-plugin/marketplace.json`이 배포 대상과 순서를 관리한다.
- skill 원본은 `plugins/*/skills/**`에 있다.
- 일부 플러그인은 `agents/`만 있고 `skills/`는 없다.

Codex 공식 문서 기준으로는 다음이 중요하다.

- skill이 저작 포맷이고, plugin은 설치/배포 단위다.
- Codex plugin은 각 plugin root에 `.codex-plugin/plugin.json`이 필요하다.
- `.codex-plugin/` 아래에는 `plugin.json`만 둔다.
- repo-local marketplace는 `.agents/plugins/marketplace.json`을 사용한다.

## Design Principles

1. **Claude-first**
   - Claude manifest와 marketplace를 계속 정본으로 둔다.
2. **Shared content**
   - skill 콘텐츠는 한 번만 작성하고 Claude/Codex가 함께 사용한다.
3. **Generated Codex artifacts**
   - Codex manifest와 marketplace는 항상 생성물로 취급한다.
4. **No speculative abstraction**
   - 새 중간 DSL이나 메타 스펙은 도입하지 않는다.
5. **Deterministic rebuild**
   - Codex 산출물은 매번 전체 재생성 가능해야 한다.

## Source of Truth

정본은 아래 세 곳이다.

1. `plugins/*/skills/**`
   - 공통 skill 콘텐츠
2. `plugins/*/.claude-plugin/plugin.json`
   - plugin 단위 메타데이터 정본
3. `.claude-plugin/marketplace.json`
   - 배포 대상 plugin 목록과 순서의 정본

Codex 관련 파일은 정본이 아니다.

- `plugins/*/.codex-plugin/plugin.json`
- `.agents/plugins/marketplace.json`

이 두 파일은 **직접 편집 금지 생성물**로 간주한다.

## Output Model

### Claude side

기존 구조를 유지한다.

```text
plugins/<name>/
├── .claude-plugin/plugin.json
└── skills/
```

루트에는 기존대로:

```text
.claude-plugin/marketplace.json
```

### Codex side

각 Codex 지원 plugin은 아래 구조를 가진다.

```text
plugins/<name>/
├── .codex-plugin/
│   └── plugin.json
└── skills/
```

루트에는 Codex marketplace를 둔다.

```text
.agents/plugins/marketplace.json
```

Codex는 기존 `skills/` 디렉터리를 그대로 재사용한다. skill 복제본은 만들지 않는다.

## Inclusion Rules

Codex plugin 생성 대상은 다음 조건을 모두 만족하는 plugin으로 제한한다.

1. `.claude-plugin/marketplace.json`의 `plugins[]`에 포함되어 있다.
2. `plugins/<name>/skills/` 디렉터리가 실제로 존재한다.

따라서 현재 구조에서는 `agents/`만 있고 `skills/`가 없는 plugin은 Codex 생성 대상에서 자동 제외된다.

이 규칙은 중요하다.

- Claude 배포 대상과 Codex 배포 대상이 완전히 같다고 가정하지 않는다.
- Codex가 공식적으로 다루는 배포 단위를 skill plugin으로 한정한다.
- `core`처럼 현재 skill 없는 plugin을 무리하게 변환하지 않는다.

## Data Mapping

### Per-plugin manifest mapping

`plugins/<name>/.claude-plugin/plugin.json`에서 `plugins/<name>/.codex-plugin/plugin.json`으로 아래 필드를 복사한다.

- `name`
- `version`
- `description`
- `author`
- `license`
- `homepage`
- `repository`
- `keywords`

Codex용 추가 필드는 아래만 넣는다.

- `skills: "./skills/"`

필요하지 않은 Claude 전용 구조는 복사하지 않는다.

### Marketplace mapping

Codex marketplace는 Claude marketplace를 기반으로 생성한다.

- plugin 순서는 Claude marketplace 순서를 그대로 따른다.
- `name`은 동일하게 유지한다.
- `source.path`는 항상 `./plugins/<name>` 상대경로를 사용한다.
- `policy.installation`, `policy.authentication`, `category`는 항상 명시한다.

초기 기본값:

- `policy.installation: "AVAILABLE"`
- `policy.authentication: "ON_INSTALL"`
- `category: "Productivity"`

향후 세분화가 필요하면 생성기 내부의 작은 매핑 테이블로 처리한다. 별도 정본 파일은 만들지 않는다.

## Generation Pipeline

Codex 산출물 생성은 별도 스크립트로 수행한다.

권장 구조:

```text
scripts/
├── generate-codex-plugin-manifests.sh
├── generate-codex-marketplace.sh
└── sync-codex-artifacts.sh
```

역할은 아래와 같다.

### `generate-codex-plugin-manifests.sh`

- Claude marketplace를 읽어 대상 plugin 목록을 정한다.
- 각 대상 plugin의 Claude manifest를 읽는다.
- `plugins/<name>/.codex-plugin/plugin.json`을 생성 또는 갱신한다.
- 대상이 아닌 plugin의 stale Codex manifest는 삭제하거나, 최소한 검증 단계에서 실패시킨다.

### `generate-codex-marketplace.sh`

- Claude marketplace의 순서를 읽는다.
- Codex 지원 대상만 필터링한다.
- `.agents/plugins/marketplace.json`을 생성 또는 갱신한다.

### `sync-codex-artifacts.sh`

- 위 두 스크립트를 순서대로 호출하는 상위 진입점이다.
- CI와 로컬 검증은 이 진입점만 호출하면 된다.

## Why Full Regeneration

부분 수정 대신 전체 재생성을 채택한다.

이유:

- plugin 수가 작다.
- 생성 규칙이 단순하다.
- stale 파일 검출이 쉽다.
- 사람이 산출물을 직접 고치지 않게 강제하기 쉽다.

전체 재생성은 구현도 더 짧고 실패 조건도 더 명확하다.

## CI Contract

Codex 산출물은 git에 커밋한다. 하지만 직접 편집하지 않는다.

CI의 책임은 두 가지다.

1. 생성 스크립트를 실행해 최신 상태로 맞춘다.
2. 생성 후 diff가 남으면 실패시킨다.

권장 흐름:

1. `scripts/sync-codex-artifacts.sh`
2. JSON 유효성 검사
3. 경로 유효성 검사
4. `git diff --exit-code`

이 규칙으로 PR에서 다음 실수를 막는다.

- Claude 정본만 수정하고 Codex 산출물 갱신을 빼먹는 경우
- 생성기 로직 변경 후 생성물을 커밋하지 않은 경우
- skill 없는 plugin이 잘못 marketplace에 포함된 경우

## Test Strategy

기존 BATS 패턴을 재사용한다.

추가 테스트 후보:

- `tests/codex_plugin_json.bats`
- `tests/codex_marketplace_json.bats`

검증 항목은 아래로 제한한다.

### Codex plugin manifest tests

- 대상 plugin마다 `.codex-plugin/plugin.json`이 존재하는가
- JSON이 유효한가
- `name`, `description`, `version`, `skills`가 존재하는가
- `skills`가 `./skills/`인지
- `./skills/`가 실제 디렉터리와 일치하는가

### Codex marketplace tests

- `.agents/plugins/marketplace.json`이 존재하는가
- JSON이 유효한가
- 모든 `source.path`가 `./plugins/<name>` 형식인가
- 모든 `source.path`가 실제 plugin 디렉터리를 가리키는가
- marketplace에 포함된 plugin이 실제로 `skills/`를 갖는가
- plugin 순서가 Claude marketplace의 Codex-eligible subset과 일치하는가

### Drift tests

- 생성기 실행 후 working tree diff가 없어야 한다.

## Failure Policy

아래 상황은 실패로 본다.

- Claude marketplace에 있는 plugin이 Codex marketplace에 잘못 누락됨
- skill이 없는 plugin이 Codex marketplace에 잘못 포함됨
- Claude manifest의 버전과 Codex manifest 버전이 어긋남
- Codex manifest가 `./skills/`가 아닌 다른 경로를 가리킴
- `.codex-plugin/` 아래에 `plugin.json` 외 파일을 두는 구조로 확장됨

실패는 조용히 무시하지 않고 CI에서 명시적으로 드러나야 한다.

## Maintainer Rules

반드시 문서화할 운영 규칙:

1. `.codex-plugin/plugin.json`은 직접 수정하지 않는다.
2. `.agents/plugins/marketplace.json`은 직접 수정하지 않는다.
3. Codex 관련 변경은 Claude 정본 또는 생성 스크립트에서만 한다.
4. Codex 지원 여부는 `skills/` 존재와 Claude marketplace 등재 여부로 결정한다.

이 네 가지가 유지보수 비용을 낮추는 핵심 규칙이다.

## Rejected Alternatives

### 1. 수동 이중 관리

빠르게 시작할 수는 있지만, description/version/order 드리프트가 거의 확실하다.

### 2. Codex 중심 구조로 전환

현재 저장소의 Claude 중심 운영 흐름과 맞지 않는다. 범위도 과하다.

### 3. 공통 중간 스펙 도입

장기적으로는 깔끔해 보일 수 있지만, 지금 단계에서는 추상화 비용이 크고 실제 이득이 작다.

## References

- OpenAI Codex Skills: https://developers.openai.com/codex/skills
- OpenAI Codex Plugin Build Guide: https://developers.openai.com/codex/plugins/build
- OpenAI Codex Agents Guide: https://developers.openai.com/codex/guides/agents-md
