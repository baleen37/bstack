# delegating-tool-calls — 설계

## 목적

Claude Code에서 다중 소스(MCP·CLI·REST) 도구 호출을 할 때, **중간 결과로 메인 컨텍스트를
오염시키지 않는** 패턴을 가르치는 범용 스킬.

## 핵심 원리 (한 줄)

도구를 메인에서 직접 여러 번 부르지 말고 → **서브에이전트에 위임 → 그 안에서 코드 호출 또는
CLI로 처리 → 요약만 회수.**

## 이중 격리

```
메인 ──지시──▶ 서브에이전트 (별도 컨텍스트)
                  │
                  ├─ 코드로 stdio MCP raw JSON-RPC 호출
                  ├─ 또는 CLI 실행 (pup / ks / gh + jq)
                  │   → 중간결과(raw JSON 수십 건)는 전부 여기서 소비
                  │
              요약만 ◀── 메인은 결론만 받음
```

1. **서브에이전트 격리** — 탐색·시행착오·raw 응답이 메인 대화에 안 들어옴
2. **코드/CLI 격리** — 그 안에서도 raw 데이터는 스크립트 변수·파이프에서 처리, 서브 컨텍스트조차
   덜 씀

두 층을 합치면 토큰이 가장 적게 든다.

## API PTC와의 구분 (오해 차단)

Claude API의 정식 기능 **Programmatic Tool Calling**과 이름이 비슷하지만 **다르다**:

- API PTC: `code_execution` 컨테이너에서 모델이 커스텀 도구를 코드로 호출. **Claude Code에는
  없음**, MCP 커넥터 도구는 대상도 아님.
- 이 스킬: Claude Code에서 **서브에이전트가** 코드/CLI로 연동 도구를 호출하는 패턴.

SKILL.md 본문 첫머리에 이 구분을 명시한다.

## 적용 경로 (서브에이전트가 안에서 선택)

노출 형태는 4경로 매트릭스가 아니라, 위임받은 서브에이전트가 *안에서* 고르는 디테일이다.

| 대상 노출 형태 | 호출 방법 | 판별 |
| --- | --- | --- |
| MCP **stdio** (로컬) | 의존성 0 raw JSON-RPC 임시 스크립트 (node `child_process`) | `claude mcp list` → `npx`/`./bin` 등 명령 |
| MCP **리모트 OAuth** | 셸에서 직접 불가 → 서브에이전트가 MCP 도구로 호출 | `claude mcp list` → `https://...mcp` |
| **CLI** (`pup`/`ks`/`gh`) | Bash 직접 + `--output json \| jq` | `command -v` |
| **REST** (토큰 보유) | `curl` + `jq` | — |

## 검증된 함정 (스킬에 명문화)

이 세션에서 실제로 부딪힌 것:

- **도구 이름 추측 금지** → `tools/list` 먼저. (`get-library-docs` ❌ → 실제 `query-docs` ✅)
- **CLI 출력은 `--output json`** → datadog `pup`의 table 포매터가 한글 멀티바이트에서 패닉.
- **stdio MCP는 SDK 불필요** → node `child_process`로 newline-delimited JSON-RPC면 충분(의존성 0).
- **핸드셰이크 순서** → `initialize` → `notifications/initialized` → `tools/call`.

## 언제 안 쓰나

1~2회 단순 조회는 그냥 메인에서 직접. 위임 오버헤드(서브 컨텍스트 spin-up)가 더 크다.

## 위치 / 유형 / 패키징

- 위치: `plugins/me/skills/delegating-tool-calls/`
- 유형: Technique + 약간의 Pattern
- 스크립트: SKILL.md 지시문이 기본. raw JSON-RPC 최소 예제는 reference 파일로 번들.
  메모리 `feedback_avoid_helper_script_overengineering` 존중 — 본문은 지시문 위주, 범용 헬퍼
  강제 분리는 지양(케이스마다 임시 스크립트를 찍어내는 방식).

## 제작 방법론 (Iron Law)

writing-skills RED→GREEN→REFACTOR. 스킬 작성 전 베이스라인(스킬 없이 서브에이전트 실패) 먼저
관찰하고, 그 실패만 겨냥해 작성한다. 사용자 요청의 "다양한 케이스 테스트하며 점진 개선"이 곧
이 사이클이다.
