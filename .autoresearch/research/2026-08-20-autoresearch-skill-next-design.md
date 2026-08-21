# autoresearch 스킬 다음 설계 조사

**작성일**: 2026-08-20
**대상**: `plugins/autoresearch/skills/autoresearch/SKILL.md`

## 결론

현재 스킬에 더 많은 복구 규칙과 도구를 추가하는 방향은 권장하지 않는다.

권장안은 다음과 같다.

1. 현재 범용 `.autoresearch/` 구조는 유지한다.
2. upstream처럼 실행 규칙을 짧게 유지한다.
3. 결과 ledger는 하나만 둔다. `results.jsonl` 또는 upstream식 `results.tsv` 중 하나를 선택한다.
4. Git 조작은 `git add <files-in-scope>`와 실험 커밋 전후의 명확한 기준점만 문서화한다.
5. 장시간 실행은 별도 선택 모드로 둔다. 기본 스킬이 provider별 shell loop를 강제하지 않는다.
6. GEPA는 기본 엔진으로 통합하지 않고, 단일 text artifact 최적화용 별도 선택지로 안내한다.

## 확인한 최신 upstream

`karpathy/autoresearch`의 최신 `master`는 2026-08-20 확인 시 `228791fb499afffb54b46200aca536f79142f117`이었다.
upstream의 `program.md`는 다음을 사용한다.

- 새롭고 유일한 `autoresearch/<tag>` branch
- baseline을 먼저 실행
- 고정 시간 예산
- 실험 커밋 후 실행
- `results.tsv`는 Git에 커밋하지 않는 append-only 결과 파일
- metric 개선 시 commit 유지, 아니면 이전 상태로 reset

출처: [upstream program.md](https://github.com/karpathy/autoresearch/blob/master/program.md), [upstream README](https://github.com/karpathy/autoresearch/blob/master/README.md)

현재 스킬은 이미 upstream보다 범용적이며 `PIPESTATUS`, noisy metric, Goodhart 방지 규칙을 추가하고 있다. 이 세 가지는 유지할 가치가 있다.

## 대안 비교

### 1. upstream식 단일 ledger

`results.tsv`는 구조가 단순하고 `jq`가 필요 없다. upstream은 commit, primary metric, memory, status, description만 기록한다. 이 스킬처럼 여러 metric과 임의 repo를 지원하려면 TSV 열을 늘리거나 JSONL을 사용해야 한다.

판정: 범용 스킬의 기본 포맷으로 JSONL을 유지해도 된다. 다만 JSONL을 쓸 경우 `jq`를 필수 도구로 명시하고, 모든 행을 `jq -nc`로 생성한다. 두 포맷을 동시에 지원하면 안 된다.

### 2. progress file + Git history

Anthropic은 장기 실행 agent의 fresh context handoff에 progress file과 Git history를 함께 사용한다. 초기 agent는 환경 초기화 스크립트, progress 파일, 초기 commit을 만들고, 후속 agent는 progress와 Git log를 읽고 작업 후 commit과 progress update를 남긴다.

현재 `.autoresearch/autoresearch.md`의 `What's Been Tried`가 progress file 역할을 한다. 별도의 `worklog.md`를 다시 추가할 근거는 부족하다.

출처: [Anthropic, Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents), [Anthropic, Harness design for long-running application development](https://www.anthropic.com/engineering/harness-design-long-running-apps)

### 3. Git worktree를 기본 격리 계층으로 사용

Git 공식 문서상 worktree는 같은 repository에서 여러 branch를 독립 working tree로 checkout할 수 있다. 사용자의 현재 dirty worktree를 보존하고 병렬 실험을 실행하는 데는 적합하다.

하지만 기본 workflow에 넣으면 path 생성, dependency/cache 공유, cleanup, branch ownership 문제가 새로 생긴다. 현재 스킬은 한 agent가 한 working tree에서 실행하는 것이 기본이므로, worktree는 다음 경우에만 선택한다.

- 현재 working tree가 dirty이고 사용자 변경과 분리해야 할 때
- 여러 실험 agent를 병렬로 돌릴 때
- benchmark가 장시간 실행되어 원래 작업 디렉토리를 차단할 때

출처: [Git git-worktree documentation](https://git-scm.com/docs/git-worktree)

### 4. GEPA `optimize_anything`

GEPA의 최신 공식 문서는 `optimize_anything`을 code, prompt, config 등 text로 표현 가능한 artifact를 평가 함수와 함께 진화시키는 API로 설명한다. evaluator의 error, trace, profiler output을 ASI(Actionable Side Information)로 넘겨 다음 후보 생성에 활용할 수 있고, timeout과 no-improvement stopper도 제공한다.

이것은 단일 파일이나 단일 artifact에는 현재 agent loop보다 강력할 수 있다. 그러나 기본 의존성이 Python이고, 여러 파일을 자유롭게 수정하는 repository workflow와 Git commit/revert를 직접 대체하지 않는다.

판정: autoresearch 스킬에 GEPA를 내장하지 않는다. 나중에 다음 조건을 만족할 때 별도 skill 또는 실행 모드로 추가한다.

- 최적화 대상이 하나의 text artifact로 직렬화 가능
- evaluator와 후보 생성 비용을 Python 의존성으로 감당 가능
- multi-task 또는 Pareto frontier가 실제로 필요

출처: [GEPA API](https://gepa-ai.github.io/gepa/api/optimize_anything/optimize_anything/), [GEPA guide](https://github.com/gepa-ai/gepa/blob/main/docs/docs/guides/index.md), [GEPA README](https://github.com/gepa-ai/gepa)

## 권장 변경안

현재 working diff에서 다음만 남기는 것이 가장 낫다.

### 유지

- baseline 선실행
- unique branch
- `PIPESTATUS`로 benchmark exit code 확인
- `git add -A` 금지
- ledger와 benchmark 산출물을 실험 commit에서 제외
- noisy metric의 반복 측정
- metric이 좋아진 이유가 실제 개선인지 확인

### 축소

- committed reset 전에 ledger tracked 여부를 매번 검사하라는 긴 절차 삭제
- timeout을 스킬 규칙으로 강제하지 말고 `run.sh`의 benchmark 계약으로 한 문장만 유지
- provider별 `claude -p` shell loop는 기본 workflow에서 분리
- discard/crash 복구 명령 예시는 한 가지 canonical path만 제공

### 추가하지 않음

- `dashboard.md`, `worklog.md`, 별도 database
- MLflow, DVC, W&B
- GEPA runtime dependency
- 기본 worktree 생성
- multi-agent orchestration

## 최종 판단

현재 수정안은 ledger 보호를 위해 필요한 핵심은 맞지만, 복구 설명이 스킬 본문에 너무 많이 들어갔다. 다음 구현 단계에서는 다음 형태가 적절하다.

> `program.md` 역할의 objective 파일 + 하나의 append-only ledger + Git commit history + 선택적 shell-driven resume

이 네 요소가 현재 문제를 해결하면서 upstream과 Anthropic의 검증된 패턴을 모두 보존한다.

## 웹 재검증: 2026-08-20

### Upstream 상태

현재 upstream `program.md`는 여전히 단일 agent, 고정 5분 실행, baseline 선실행, branch별 untracked `results.tsv`, 개선 시 commit 유지라는 구조다. 최신 upstream의 핵심은 orchestration framework가 아니라 사람이 작성하는 `program.md`와 짧고 반복 가능한 evaluator 계약이다.

출처: [karpathy/autoresearch program.md](https://github.com/karpathy/autoresearch/blob/master/program.md), [karpathy/autoresearch README](https://github.com/karpathy/autoresearch/blob/master/README.md)

### ShinkaEvolve

ShinkaEvolve는 2026년 현재 Codex/Claude용 `shinka-setup`, `shinka-convert`, `shinka-run`, `shinka-inspect` skill을 제공한다. 하지만 사용자가 `evaluate.py`와 `initial.py`를 준비하고, `EVOLVE-BLOCK` 범위를 지정하며, 여러 후보를 population/island로 관리하는 구조다. 병렬 evaluator와 WebUI도 제공한다.

판정: 범용 autoresearch skill의 내부 구현으로 가져오지 않는다. 과학 코드나 명확한 verifier가 있고 population search가 필요한 별도 workflow의 후보로 기록한다.

출처: [ShinkaEvolve README](https://github.com/SakanaAI/ShinkaEvolve/blob/main/README.md), [ShinkaEvolve agentic usage](https://github.com/SakanaAI/ShinkaEvolve/blob/main/docs/agentic_usage.md)

### OpenEvolve

OpenEvolve는 최신 릴리스에서 MAP-Elites archive, island-based evolution, LLM ensemble, artifact side-channel, parallel evaluation, checkpoint와 timeout을 제공한다. 공식 기본 설정만 해도 population, archive, islands, migration, feature dimensions, cascade evaluation 등의 설정이 필요하다.

판정: metric 하나를 기준으로 한 순차 repo loop의 단순한 개선안이 아니다. 후보 다양성과 병렬 throughput이 목적일 때만 별도 도구로 선택한다.

출처: [OpenEvolve README](https://github.com/algorithmicsuperintelligence/openevolve/blob/main/README.md), [OpenEvolve default configuration](https://github.com/algorithmicsuperintelligence/openevolve/blob/main/configs/default_config.yaml), [OpenEvolve releases](https://github.com/algorithmicsuperintelligence/openevolve/releases)

### 웹 조사 최종 판단

현재 스킬을 ShinkaEvolve나 OpenEvolve처럼 확장하는 것은 개선이 아니라 제품 범위 변경이다. 가장 좋은 기본안은 upstream의 단순한 loop를 유지하고, 다음 두 가지 선택 모드만 별도로 제공하는 것이다.

- `repo-loop`: 현재 스킬. 여러 파일, Git commit/revert, 하나의 primary metric.
- `artifact-evolution`: GEPA/Shinka/OpenEvolve를 사용해야 할 때의 별도 workflow. evaluator, 후보 표현, Python 의존성, population 정책을 명시한다.

기본 `repo-loop`에 population, Pareto archive, WebUI, database, multi-agent coordinator를 추가하지 않는다.

### OpenAI harness engineering과의 비교

OpenAI의 Codex harness 사례는 agent가 작업할 수 있는 환경을 더 복잡하게 만드는 것보다, 다음을 repository 안에서 직접 읽고 실행할 수 있게 만드는 데 초점을 둔다.

- worktree별로 앱을 부팅할 수 있는 실행 경로
- 로그와 metric을 agent가 조회할 수 있는 관측성
- 문서, 계획, 품질 기준을 repository 안에 두는 progressive disclosure
- 불변 조건을 문서가 아니라 CI와 도구로 강제

autoresearch에 적용할 때 가장 작은 형태는 `.autoresearch/run.sh`를 단순 benchmark wrapper에 그치게 하지 않고, metric 형식 검증과 실행 로그 경로까지 책임지게 하는 것이다. Git reset 절차를 SKILL.md에 길게 설명하는 것보다 다음 계약이 더 효과적이다.

```text
run.sh 성공 + primary metric 정확히 1개 출력
run.sh 실패 또는 metric 누락 = crash
로그 경로와 metric 이름은 autoresearch.md에 고정
keep/discard 판단과 Git commit은 agent가 수행
```

worktree별 boot나 별도 observability stack은 실제 서비스 E2E나 병렬 agent가 필요할 때만 추가한다.

출처: [OpenAI, Harness engineering: leveraging Codex in an agent-first world](https://openai.com/index/harness-engineering/)
