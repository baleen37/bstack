# autoresearch 플러그인 기본 동작 조사

**작성일**: 2026-08-21
**대상**: `plugins/autoresearch`

## 결론

첫 개선은 기능 확장이 아니라 기본 실행 계약을 명확하게 만드는 것이 적절하다.

최소 루프는 다음 순서를 보장해야 한다.

```text
setup -> baseline -> experiment -> benchmark -> metric 판정
       -> keep/discard/crash -> ledger 기록 -> resume
```

현재 플러그인은 실험 중 규칙은 비교적 잘 설명하지만, setup 단계와 실행 진입점 사이의 연결이 약하다. 특히 baseline을 언제 실행하고 `.autoresearch/results.jsonl`의 첫 행을 어떻게 만드는지가 skill 본문과 command에 분산되어 있다.

## Upstream 기본 동작

`karpathy/autoresearch`의 공식 `program.md`와 `README.md`에서 확인한 기본 동작은 다음과 같다.

- 새롭고 유일한 `autoresearch/<tag>` 브랜치에서 시작한다.
- `README.md`, 고정 평가/데이터 로더, 실험 대상을 먼저 읽는다.
- 변경 대상과 평가 하네스를 분리한다. upstream에서는 `train.py`만 수정하고 `prepare.py`의 평가 함수를 수정하지 않는다.
- 첫 실행은 baseline이다.
- 각 실험은 변경, commit, benchmark 실행, metric 추출, keep/discard/crash 판정, 결과 기록 순서로 진행한다.
- 고정된 실행 예산을 사용한다. upstream 기준 학습 시간은 5분이다.
- 개선되지 않은 실험은 이전 상태로 되돌리고, 결과 ledger는 실험 commit과 분리한다.
- 사용자가 중단할 때까지 반복한다.

출처: [upstream program.md](https://github.com/karpathy/autoresearch/blob/master/program.md), [upstream README.md](https://github.com/karpathy/autoresearch/blob/master/README.md)

## 현재 플러그인 관찰

현재 `plugins/autoresearch`에는 다음 요소가 있다.

- `skills/autoresearch/SKILL.md`: 범용 Git 실험 루프와 JSONL ledger 규칙
- `commands/autoresearch.md`: Claude Code용 fresh/resume/off 진입점
- `hooks/autoresearch-context.sh`: 활성 상태에서 매 사용자 메시지에 루프 문맥 주입
- `.codex-plugin/plugin.json`: Codex에는 shared `skills/`를 노출

확인된 기본 동작상의 seam은 다음과 같다.

1. skill setup은 `autoresearch.md`와 `run.sh`를 만들고 setup 파일만 commit하라고 하지만, baseline 실행과 첫 ledger 행 기록의 시점이 setup 절차 안에 명시적으로 닫혀 있지 않다.
2. command resume은 `.autoresearch/results.jsonl`을 전제로 통계를 복원하지만, fresh setup에서 해당 파일을 생성하는 계약이 보이지 않는다.
3. skill은 `NEVER STOP`을 기본 루프 규칙으로 둔다. 이는 사용자가 “한 번 실행”을 요청하는 경우와 충돌할 수 있다.
4. command는 Claude Code의 수동 진입점이고, Codex manifest는 skill만 노출한다. 두 runtime에서 같은 기본 동작이 실제로 시작되는지는 각각 검증해야 한다.
5. `results.jsonl`은 upstream의 `results.tsv`와 다른 형식이다. 이는 허용 가능한 adapter지만, `commit`, `metric`, `status`, `description`의 의미와 append-only 원칙은 유지되어야 한다.

## 최소 실행 계약

플러그인이 보장해야 할 계약은 다음 여섯 가지로 제한한다.

1. **목표 계약**: 최적화 대상, primary metric, 방향, 실행 명령, 수정 가능 파일, 금지 파일을 `autoresearch.md`에 적는다.
2. **baseline 계약**: 변경 전에 benchmark를 한 번 실행하고, 성공 여부와 metric을 ledger 첫 행에 기록한다.
3. **실행 계약**: benchmark 종료 코드와 `METRIC name=number` 출력을 확인한다. 종료 실패 또는 primary metric 누락은 `crash`다.
4. **판정 계약**: 개선이면 `keep`, 동률/악화면 `discard`하고 실험 변경만 되돌린다.
5. **상태 계약**: 실험 commit과 ledger를 분리하고, `autoresearch.md`, ledger, Git log만 읽어도 재개할 수 있다.
6. **종료 계약**: 단일 실행과 계속 반복을 구분한다. 기본 명령은 한 iteration으로도 사용할 수 있고, 명시적 loop 모드만 계속 반복해야 한다.

## 첫 구현 범위

첫 변경은 다음 세 가지면 충분하다.

1. setup 직후 baseline 실행과 첫 JSONL 행 기록을 skill의 필수 순서로 고정한다.
2. `run.sh`의 primary metric 정확히 1개, 비정상 종료, metric 누락을 공통 실행 계약으로 명시한다.
3. 단일 iteration과 무한 loop를 구분하는 진입점 문구를 정리한다. 기존 Git 안전 규칙, noisy metric 규칙, `PIPESTATUS`, `jq -nc`는 유지한다.

추가하지 않을 것:

- population/island search, GEPA, database, dashboard
- 기본 worktree orchestration
- provider별 장시간 shell loop 강제
- 두 개 이상의 ledger 형식 지원

## 검증 기준

- 새 프로젝트에서 fresh setup 후 `.autoresearch/autoresearch.md`, `.autoresearch/run.sh`, `.autoresearch/results.jsonl`이 모두 존재한다.
- baseline이 실험 변경 전에 실행되고 ledger 첫 행의 `status`와 metric이 유효하다.
- benchmark 비정상 종료와 metric 누락이 각각 `crash`로 기록된다.
- metric 개선 실험은 keep, 동률/악화 실험은 discard 후 scope 파일만 원복된다.
- resume이 ledger와 Git log에서 baseline, best, 최근 상태를 복원한다.
- Codex manifest/skill 및 Claude plugin/command 검증이 통과한다.

## 공식 플러그인 문서

Codex 공식 문서는 플러그인이 skill 같은 workflow guidance를 패키징한다고 설명한다. [Plugins in Codex](https://help.openai.com/en/articles/20001256-plugins-in-codex)

Claude Code 공식 문서는 plugin root 아래 `skills/`, `commands/`, `hooks/`를 두고 `.claude-plugin/plugin.json`에는 manifest만 둔다고 설명한다. [Create plugins](https://code.claude.com/docs/en/plugins), [Plugins reference](https://code.claude.com/docs/en/plugins-reference)

이 문서들은 autoresearch 전용 실행 semantics를 정의하지 않는다. 따라서 위 실행 계약은 upstream loop와 각 runtime의 plugin packaging 규칙을 결합한 로컬 계약이다.

## 추가 웹 재검증: 더 단순한 방법

2026-08-21에 공식 문서를 다시 비교한 결과, 첫 구현은 다음처럼 축소하는 것이 가장 낫다.

### 채택

`SKILL.md` 하나를 focused workflow로 유지하고, `run.sh`와 `results.jsonl`을 supporting files로 둔다.

```text
focused SKILL.md
  -> setup / baseline / one experiment / evaluate / keep-discard
run.sh
  -> bounded benchmark + METRIC 출력
results.jsonl
  -> append-only 상태
```

upstream도 `program.md`에 연구 규칙과 변경 경계를 두고, 실행 파일과 결과 파일을 단순하게 분리한다. Codex 공식 plugin 구조도 `plugin.json`과 `skills/`를 핵심으로 보고, 추가 lifecycle 자동화는 선택 사항으로 둔다. 출처: [karpathy/autoresearch program.md](https://github.com/karpathy/autoresearch/blob/master/program.md), [Codex plugin architecture](https://developers.openai.com/plugins/concepts/plugins), [Package your plugin](https://developers.openai.com/plugins/build/plugins)

### 보류

Claude hook으로 자동 시작, 자동 반복, ledger 기록을 강제하지 않는다.

Claude 공식 문서에서 skill은 판단이 필요한 workflow에, hook은 매번 동일하게 실행되어야 하는 결정적 제어에 적합하다고 구분한다. 현재 `UserPromptSubmit` hook은 loop를 진행시키거나 ledger를 검증하지 않고 매 사용자 메시지에 `NEVER STOP` 문맥만 추가한다. 따라서 실질적 보장보다 문맥 비용과 runtime 차이를 늘린다. 출처: [Claude hooks guide](https://code.claude.com/docs/en/hooks-guide), [Claude features overview](https://code.claude.com/docs/en/features-overview)

첫 구현에서는 hook을 제거하거나 최소한 비활성화하고, 명시적인 skill/command가 setup과 iteration을 수행하게 하는 편이 단순하다. hook이 다시 필요해지는 시점은 `git reset` 차단이나 ledger 형식 검증처럼 모델 판단 없이 항상 같은 방식으로 막아야 하는 규칙이 생길 때다.

## subagent 추가 조사: loop 운전 주체

추가 조사 결과, 가장 작은 책임 분리는 다음과 같다.

```text
shell loop
  └─ agent 1회 실행
       ├─ 한 가지 변경
       ├─ benchmark 실행
       ├─ keep / discard / crash 판단
       └─ ledger 1줄 기록
```

### 채택

shell이 반복 횟수, timeout, 중단, 재시작, 비용 제한을 담당하고 agent는 한 번의 원자적 iteration만 수행한다.

이 구조는 장시간 session context에 의존하지 않고, 각 iteration을 새 context에서 재개할 수 있다. Karpathy upstream의 핵심도 결국 한 변경, 실행, 측정, keep/discard의 원자적 순서다. [upstream program.md](https://github.com/karpathy/autoresearch/blob/master/program.md)

ledger는 유지한다. 최소 필드는 다음 네 개면 충분하다.

```json
{"commit":"abc1234","metric":8.42,"status":"keep","description":"short change"}
```

이 네 필드로 baseline/best 복원, keep/discard/crash 구분, 새 session 재개가 가능하다. upstream도 같은 의미의 commit, metric, status, description을 결과 파일에 기록한다. [upstream logging rules](https://github.com/karpathy/autoresearch/blob/master/program.md)

### 보류

Anthropic의 공식 Ralph Loop처럼 Stop hook이 agent의 종료를 가로채 같은 prompt를 반복 주입하는 방식은 autoresearch 기본 구현에 채택하지 않는다. 공식 Ralph 구현은 동작하지만 loop 제어가 session 내부에 숨고, 종료/재시작/iteration 제한을 shell보다 관찰하기 어렵다. [Anthropic Ralph Loop README](https://github.com/anthropics/claude-plugins-official/blob/main/plugins/ralph-loop/README.md), [Ralph command](https://github.com/anthropics/claude-code/blob/main/plugins/ralph-wiggum/commands/ralph-loop.md)

Claude 공식 문서도 hook은 결정적 lifecycle 제어, skill은 판단이 필요한 workflow로 구분한다. 따라서 autoresearch 반복 자체는 skill 또는 외부 shell이 담당하고, hook은 위험한 Git 명령 차단이나 고정 검증처럼 결정적인 guardrail에만 남기는 게 맞다. [Claude features overview](https://code.claude.com/docs/en/features-overview)

## 최종 단순안

```text
setup:
  autoresearch.md 생성
  run.sh 생성
  baseline 실행
  results.jsonl에 baseline 기록

iteration:
  새 agent session 시작
  한 가지 변경
  run.sh 실행
  metric 판정
  keep/discard/crash 기록

controller:
  shell이 iteration 재호출
  timeout/횟수/중단을 외부에서 제어
```

현재 플러그인에서 첫 변경할 대상은 `UserPromptSubmit` context hook이 아니라, setup과 iteration의 경계를 `SKILL.md`에 명확히 적는 것이다. 반복 controller는 이후 실제 unattended 실행 요구가 확인될 때 별도 shell script로 추가한다.
