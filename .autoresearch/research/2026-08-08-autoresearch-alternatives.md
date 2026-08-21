# autoresearch 대안 조사: 더 쉽고, 더 일반적이고, 더 단순한 것이 있는가

**작성일**: 2026-08-08
**대상**: `plugins/autoresearch/skills/autoresearch/SKILL.md`

> **디렉토리 규칙 note**: 이 레포는 설계 문서를 `docs/superpowers/plans/YYYY-MM-DD-<topic>.md`에 둡니다. 이 문서는 plan이 아니라 research이므로 형제 디렉토리 `docs/superpowers/research/`를 새로 만들어 같은 date-prefix 규칙을 따랐습니다.

---

## 결론 먼저

**현재 설계보다 "의미 있게 더 단순한" 범용 대안은 없습니다.** 다만 두 가지 진짜 발견이 있습니다.

1. **현재 설계는 Anthropic 자사 first-party 가이드와 거의 일치합니다.** "progress file + git history"로 fresh context에 state를 넘기는 방식은 Anthropic이 long-running agent harness의 핵심 메커니즘으로 명시한 것과 같습니다. 즉 지금 구조는 임기응변이 아니고 **문서화된 best practice**입니다. 이건 "바꿀 필요 없다"는 근거로 쓸 수 있습니다.
2. **단 하나, 진짜로 더 단순하면서 더 일반적인 것이 있습니다: GEPA의 `optimize_anything`.** evaluator 함수 하나(`(candidate: str) -> float`)만 쓰면 keep/discard/ledger/dashboard 루프 전체가 라이브러리 안으로 사라집니다. 대신 **적용 범위가 다릅니다** — 단일 text artifact를 최적화하는 것이지, 임의 repo의 여러 파일을 수정하는 게 아닙니다. 그래서 autoresearch의 **대체가 아니라 특수 케이스용 옵션**입니다.

나머지(OpenEvolve, ShinkaEvolve, MLflow, DVC, DSPy optimizer들)는 모두 **moving parts가 현재보다 많습니다.** 단순화 요구에는 역행합니다.

---

## Axis 1: autonomous experiment / self-improvement loop 기법

### 1-1. Anthropic 자사 가이드 (★ 가장 중요한 발견)

**「Effective harnesses for long-running agents」 (2025-11-26)** 는 long-running agent의 state 관리 메커니즘을 명시합니다.

> "the key insight here was finding a way for agents to quickly understand the state of work when starting with a fresh context window, which is accomplished with the `claude-progress.txt` file alongside the git history."

여기서 권장된 메커니즘들과 현재 autoresearch 스킬의 대응 관계:

| Anthropic 권장 메커니즘 | autoresearch 현재 상태 |
| --- | --- |
| progress file + git history로 state handoff | ✅ `worklog.md` + `autoresearch.md` + git log |
| git commit log로 문제 커밋 식별/revert | ✅ keep=commit / discard=checkout |
| feature list를 JSON으로 두고 "failing" 마킹 (조기 종료 방지) | △ `ideas.md`가 유사하지만 상태 마킹은 없음 |
| 세션 시작 시 e2e 검증 먼저 실행 | ✅ `run.sh` 재실행 |
| `init.sh` — context reset 후 환경 즉시 기동 | ✅ `run.sh`가 겸함 |

**「Harness design for long-running application development」 (2026-03-24)** 는 planner/generator/evaluator 3-agent 구조를 다루는데, 여기서 autoresearch에 직접 쓸 만한 건 두 가지입니다.

- 파일을 통한 통신: "One agent would write a file, another agent would read it and respond either within that file or a new file that the previous agent would read in turn."
- 주관적 판정을 구체적 기준으로 치환: "Is this design beautiful?"을 "does this follow our principles for good design?"로 바꿔 "something concrete to grade against"를 만든다.

또한 **context reset의 필요성이 모델 세대에 따라 줄었다**는 서술이 중요합니다. Opus 4.5는 "context anxiety" 때문에 sprint 분해와 context reset이 필요했지만, "Opus 4.6...improved substantially on long-context retrieval"이라 "coherently for over two hours without the sprint decomposition that Opus 4.5 had needed"가 됐다고 합니다. → **루프 구조를 더 잘게 쪼개는 방향의 개선은 수익이 줄어드는 중입니다.**

### 1-2. Ralph Loop

Geoffrey Huntley, **2025-07-14** 원글. 구현 전체가 한 줄입니다.

```bash
while :; do cat PROMPT.md | claude-code ; done
```

원칙: filesystem-as-memory (`fix_plan.md`, `AGENT.md`, `specs/*`), "Ralph is monolithic. Ralph works autonomously in a single repository as a single process that performs one task per loop."

후속 에세이 **「everything is a ralph loop」 (2026-01-17)** 도 같은 monolithic 원칙을 유지하며 "It's important to _watch the loop_"를 강조합니다.

**평가**: Ralph는 autoresearch보다 단순하지만, **metric 기반 keep/discard 판정이 없습니다.** autoresearch가 Ralph에 추가한 것이 정확히 그 판정 로직이고, 그게 이 스킬의 존재 이유입니다. Ralph로 내려가는 건 단순화가 아니라 기능 제거입니다.

한 가지 차용할 점: Ralph는 루프를 **셸이** 돌립니다. autoresearch는 agent에게 "LOOP FOREVER"라고 지시해 **모델이** 돌립니다. 셸 루프는 context 고갈 시 자동으로 fresh context를 얻지만, agent 지시형은 context가 차면 죽습니다. (아래 적용 항목 참조.)

### 1-3. AlphaEvolve / OpenEvolve / ShinkaEvolve 계보

- **AlphaEvolve** (DeepMind, arXiv:2506.13131, 2025): **사용 불가.** 공개 저장소가 명시합니다 — "This repository does _not_ contain the code to run AlphaEvolve." 결과와 검증 코드만 있습니다.
- **OpenEvolve** (codelion/openevolve): 활발함. 최신 릴리스 **v0.3.2, 2026-07-18**. 사용자가 써야 할 것: initial program + evaluator + YAML config. moving parts: LLM ensemble, island-based population, MAP-Elites quality-diversity grid, artifact side-channel, feature dimensions.
- **ShinkaEvolve** (SakanaAI): 활발함(마지막 push **2026-07-31**, archived 아님, Apache-2.0, ★1.3k). 사용자가 써야 할 것: `evaluate.py` + `initial.py`(코드에 `EVOLVE-BLOCK-START/END` 마커 삽입). moving parts: mutation LLM, population/archive, island 전략, local/SLURM 실행, DB 레이어, WebUI.

**평가**: 셋 다 **single program / marked block**을 진화시킵니다. autoresearch의 "임의 repo의 여러 파일을 자유롭게 수정"과 범위가 다릅니다. 그리고 population·island·MAP-Elites는 명백히 moving parts 증가입니다. **더 강력하지만 더 복잡하고 더 좁습니다.**

### 1-4. Claude Code / Agent SDK 프리미티브

`claude -p` 관련 프리미티브는 셸 루프를 쉽게 만들어 줍니다.

- `--continue` / `--resume <session_id>`: 공식 문서가 세션 ID 캡처 패턴을 그대로 제시합니다.
  ```bash
  session_id=$(claude -p "Start a review" --output-format json | jq -r '.session_id')
  claude -p "Continue that review" --resume "$session_id"
  ```
  v2.1.223부터는 다른 디렉토리에서도 ID로 세션을 찾습니다.
- `--output-format json` + `--json-schema`: 구조화 출력이 `structured_output` 필드로 나옵니다. **`METRIC name=number` 텍스트 파싱을 대체할 수 있는 지점입니다.**
- exit code: "exits with code 0 on success and a non-zero code when the run fails" → 셸 루프에서 분기 가능.
- `--bare`: hooks/skills/plugins/MCP/CLAUDE.md 자동 탐색을 생략해 기동이 빨라짐. 문서는 "`--bare` is the recommended mode for scripted and SDK calls, and will become the default for `-p` in a future release"라고 명시합니다. **단 autoresearch 스킬 자체가 플러그인 스킬이므로 `--bare`를 쓰면 스킬이 로드되지 않습니다** — 쓰려면 `--plugin-dir`로 명시 주입해야 합니다.

**checkpointing / `/rewind`는 git 대체가 안 됩니다.** 공식 문서가 세 가지를 명확히 못 박습니다.

- "Checkpointing does not track files modified by bash commands."
- subagent edits: "rewinding doesn't restore the edits. Use git to revert them."
- 별도 섹션 제목 그대로: **"Not a replacement for version control"** — "Checkpoints are designed for quick, session-level recovery. For permanent version history and collaboration, continue using version control, such as Git."

→ **discard 경로를 `/rewind`로 바꾸자는 아이디어는 근거 있게 기각됩니다.** `run.sh`가 bash로 만드는 산출물을 추적하지 못하고, 100 checkpoint / 30일 제한도 있습니다.

---

## Axis 2: state 관리 — "JSONL + git commit as ledger"보다 단순한 것

### 2-1. git-as-ledger는 좋은 관행인가 → 예 (first-party 근거 있음)

Anthropic 가이드가 명시적으로 progress file + git history 조합을 권장합니다(위 1-1 인용). Ralph도 filesystem + git을 state로 씁니다. **git-as-ledger를 버릴 근거는 primary source에서 찾지 못했습니다.**

### 2-2. MLflow

기본 동작이 서버 없이 로컬입니다 — "By default, without any particular server/database configuration, MLflow Tracking logs data to the local `mlruns` directory." 최소 코드:

```python
import mlflow
with mlflow.start_run():
    mlflow.log_metric("val_loss", val_loss)
```

문서 기준 버전은 MLflow 3.

**평가**: metric 기록만 보면 확실히 짧습니다. 하지만 (a) Python 의존성이 추가되고 — 이 레포의 스킬 스크립트 규칙은 **TypeScript + bun**입니다, (b) autoresearch는 metric 기록만 하는 게 아니라 **keep/discard 결정 + code revert**를 합니다. MLflow는 그 부분을 전혀 해주지 않습니다. (c) `mlruns/` 디렉토리는 사람이 읽는 dashboard가 아니라 UI를 띄워야 합니다. **JSONL 한 파일보다 단순하지 않습니다.**

### 2-3. DVC experiments

메커니즘이 흥미롭습니다: "Experiments are custom Git references (found in `.git/refs/exps`) with one or more commits based on `HEAD`." — 브랜치 히스토리를 더럽히지 않고 git 안에 실험을 쌓습니다. 파이프라인이 필수는 아니며 DVCLive로 코드에서 직접 로깅도 가능합니다.

**평가**: 개념적으로 autoresearch가 원하는 것("실험마다 커밋하되 히스토리를 더럽히지 않기")에 가장 근접한 기성품입니다. 하지만 DVC 설치 + `dvc exp` 워크플로 학습 + DVCLive가 추가됩니다. 현재는 `git commit` + 한 줄 append로 끝나는 일입니다. **트레이드오프가 좋지 않습니다.**

### 2-4. `git notes`

공식 문서: "Adds, removes, or reads notes attached to objects, without touching the objects themselves." `git log`에 자동 표시되고 `notes.displayRef`, `notes.rewrite.*` 같은 설정이 필요합니다.

**평가**: metric을 커밋에 붙이는 데는 개념적으로 깔끔합니다. 그러나 (a) discard된 실험은 붙일 커밋이 없습니다 — autoresearch는 discard 결과도 기록해야 하는데 notes는 object에 붙는 구조라 여기서 깨집니다. (b) push/fetch에 기본 refspec으로 따라가지 않아 별도 설정이 필요합니다. (c) `jq`로 읽는 JSONL보다 조회가 불편합니다. **부적합.**

### 2-5. W&B / Aim

- W&B: 오프라인 모드가 존재하지만 문서 확인 시점에 해당 FAQ 페이지에서 전문을 얻지 못했습니다(발췌만 노출). 계정/클라우드 지향이라 로컬 단독 루프에는 과합니다. **근거 불충분 — 판단 보류하되 "단순화"라고 주장할 수 없습니다.**
- Aim: 문서 페이지가 HTTP 429로 접근 실패했습니다. **확인 못 했습니다.** 이 항목은 검증되지 않았음을 명시합니다.

### 2-6. 퍼스트파티가 run history를 대신 제공하는가 → 아니오

Claude Code는 session transcript와 checkpoint를 저장하지만, 위에서 본 대로 checkpoint는 30일/100개 제한이며 bash 산출물을 추적하지 않고 명시적으로 VCS 대체가 아닙니다. **"metric 시계열 + keep/discard 결정 이력"을 제공하는 퍼스트파티 기능은 없습니다. 자체 ledger가 여전히 필요합니다.**

---

## Axis 3: metric 기반 최적화 프레임워크

### 3-1. GEPA `optimize_anything` (★ 유일하게 "더 단순 + 더 일반")

패키지 최신 버전 **0.1.4 (2026-07-15)**, Python 3.10~3.14. `optimize_anything` 소개 글은 **2026-02-18**.

핵심 주장: "If you can measure it, you can optimize it: prompts, code, agent architectures, scheduling policies, vector graphics, and more."

최소 예제 전체가 이만큼입니다.

```python
import gepa.optimize_anything as oa

def evaluate(candidate: str) -> float:
    score, diagnostic = run_my_system(candidate)
    oa.log(f"Error: {diagnostic}")
    return score

result = oa.optimize_anything(
    seed_candidate="<your initial artifact>",
    evaluator=evaluate,
)
```

- **최적화 대상**: single-task search mode에서는 **candidate 자체가 코드/artifact**입니다. dataset/valset을 주지 않습니다.
- **사용자가 쓰는 것**: evaluator 함수 하나. `(candidate: str) -> float` 또는 `-> tuple[float, dict]`.
- **moving parts**: 1개(evaluator). keep/discard, Pareto 아카이브, 반영(reflection) 루프가 라이브러리 내부.
- **핵심 개념 ASI (Actionable Side Information)**: evaluator가 `oa.log()`로 error message, profiler 출력, reasoning log를 흘려보내면 reflection LM이 그걸 읽고 다음 후보를 만듭니다. 문서는 이를 "the text-optimization analogue of a gradient"로 설명합니다. **autoresearch가 지금 사람/agent의 머릿속에서 하는 "왜 실패했나 읽고 다음 아이디어 내기"를 형식화한 것입니다.**
- **실측 사례(CUDA kernel, KernelBench, V100 32GB)**: "87% of generated kernels match or beat the baseline, with 25% achieving 20%+ speedups." evaluator가 컴파일·벤치마크하고 컴파일 에러와 profiler trace를 ASI로 반환하는 구조 — **autoresearch의 `run.sh`와 정확히 같은 역할입니다.**
- 8개 도메인(coding agents, cloud optimization, agent architecture, prompt tuning, kernel generation, circle packing, blackbox optimization, 3D graphics)에서 "consistently matches or outperforms domain-specific tools"라고 주장합니다.

**한계 (정직하게)**: candidate가 **하나의 text artifact**입니다. autoresearch는 "repo의 파일 여러 개를 자유롭게 고친다"가 전제입니다. 그걸 GEPA에 넣으려면 candidate를 patch/diff 문자열로 인코딩하거나 파일 하나로 범위를 좁혀야 합니다. 또 Python 의존성이 붙습니다. **그래서 대체재가 아니라, "최적화 대상이 단일 파일/커널/설정/프롬프트일 때"의 더 나은 도구입니다.**

### 3-2. DSPy optimizers

DSPy 공식 optimizer 선택 가이드는 상황별 표로 안내합니다(전체 목록: LabeledFewShot, BootstrapFewShot, BootstrapFewShotWithRandomSearch, KNNFewShot, COPRO, GEPA, MIPROv2, SIMBA, InferRules, BetterTogether, BootstrapFinetune, Ensemble, AvatarOptimizer). 요지: "Every optimizer tunes one or more of: instructions, demos, or weights."

- instruction 문제 + demo 양호 → COPRO 또는 GEPA
- instruction + demo 둘 다 → MIPROv2 또는 GEPA
- 식별 가능한 실패 패턴 → SIMBA 또는 InferRules
- agent/tool-use 프로그램 → AvatarOptimizer 또는 GEPA

GEPA 튜토리얼 페이지는 GEPA를 **default로 선언하지 않습니다.** "DSPy ships with several prompt optimizers"라 하고 "today we're going to focus on GEPA"라고만 합니다. GEPA의 차별점은 "a key feature is it allows our metric to provide text feedback which the LM uses to inform subsequent instructions"입니다.

> 검증 note: "GEPA is the default recommendation for DSPy in 2026", "MIPROv2보다 13% 우수 / 35x fewer rollouts" 같은 문장은 검색 결과의 **2차 블로그**들에서 나왔고 DSPy 공식 문서에서 확인되지 않았습니다. 근거로 쓰지 않았습니다.

**평가**: DSPy는 **DSPy 프로그램**(signature/module로 작성된 LLM 파이프라인)을 최적화합니다. autoresearch의 대상은 임의 repo의 코드입니다. **범위 불일치. 사용자가 써야 할 것도 DSPy 프로그램 + metric + trainset/valset으로 훨씬 많습니다.**

### 3-3. TextGrad / Optuna+LLM / 벤더 eval 제품

- TextGrad, Optuna+LLM 하이브리드: 이번 조사에서 primary source로 확인하지 못했습니다. **미검증으로 남깁니다.** (GEPA가 같은 니치를 더 직접적으로 커버하므로 우선순위를 낮췄습니다.)
- OpenAI/Anthropic의 eval+optimize 제품: autoresearch가 다루는 "임의 repo의 임의 metric"에 대응하는 first-party 제품을 확인하지 못했습니다.

### 3-4. 요약 비교표

| 도구 | 최적화 대상 | 사용자가 쓰는 것 | moving parts | 상태 |
| --- | --- | --- | --- | --- |
| **현재 autoresearch** | 임의 repo의 임의 metric | `run.sh` + SKILL 프로토콜 | 파일 5개 + git | — |
| **Ralph loop** | 아무거나 (metric 판정 없음) | `PROMPT.md` | 1 | 2025-07 원글, 2026-01 후속 |
| **GEPA `optimize_anything`** | 단일 text artifact (코드 포함) | evaluator 1개 | 1 | v0.1.4, 2026-07-15 |
| **OpenEvolve** | single program | initial + evaluator + YAML | 5+ | v0.3.2, 2026-07-18 |
| **ShinkaEvolve** | marked block이 있는 program | `initial.py` + `evaluate.py` | 6+ | push 2026-07-31 |
| **AlphaEvolve** | — | — | — | **코드 비공개** |
| **DSPy (GEPA/MIPROv2/SIMBA)** | DSPy LLM 프로그램 | 프로그램 + metric + train/val | 4+ | 현행 |
| **MLflow (local)** | (추적만) | `log_metric` 호출 | 2 | MLflow 3 |
| **DVC exp** | (추적만) | DVCLive 또는 dvc.yaml | 3+ | 현행 |
| **git notes** | (추적만) | note 설정 | 2 | discard 기록 불가 |
| **CC checkpointing** | (복구만) | 없음 | 0 | **VCS 대체 아님(공식 명시)** |

---

## 이 스킬에 실제로 적용할 만한 것

### A. 진짜로 더 단순해지는 것 (복잡도 감소 또는 무증가)

**A1. `run.sh`를 `--json-schema`로 대체하지 말고, `METRIC` 파싱 규칙을 유지하되 exit code 분기를 명문화**
현재 SKILL.md는 `EXIT_CODE=$?`를 `tee` 파이프라인 뒤에서 읽습니다. 이건 **파이프라인의 마지막 명령(`tee`)의 종료코드**를 잡으므로 crash 감지가 새는 버그입니다. `set -o pipefail`이나 `PIPESTATUS`가 필요합니다. 공식 문서가 "exits with code 0 on success and a non-zero code when the run fails, so your scripts can branch on the exit status"라고 exit code 분기를 전제하는 만큼, 이 지점은 정확해야 합니다.
근거: [Run Claude Code programmatically](https://code.claude.com/docs/en/headless)
→ **복잡도 증가 없음. 순수 버그 수정.**

**A2. "루프를 셸에 맡기는" 실행 모드를 문서에 한 줄 추가**
현재는 agent에게 "LOOP FOREVER / NEVER STOP"을 지시합니다. context가 차면 루프가 끝납니다. Ralph의 원본 형태(`while :; do ... done`)를 쓰면 매 iteration이 fresh context를 받습니다. 이미 스킬이 `worklog.md`/`autoresearch.md`/JSONL로 resume 가능하게 설계돼 있으므로 **추가 기계장치 없이** 셸 루프만 붙이면 됩니다.
근거: [ghuntley.com/ralph/](https://ghuntley.com/ralph/) (`while :; do cat PROMPT.md | claude-code ; done`), [Effective harnesses](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents) (progress file + git history로 fresh context handoff)
→ **파일 추가 0개. 문서 한 섹션.**

**A3. `ideas.md`에 상태 마킹 추가 (`- [ ]` / `- [x]` / `- [~]`)**
Anthropic 가이드의 "feature list를 JSON으로 두고 failing 마킹" 아이디어를 최소 형태로 차용. 현재 `ideas.md`는 순수 bullet이라 resume한 agent가 이미 시도한 아이디어를 재시도할 수 있습니다. `worklog.md`와 교차 확인해야 알 수 있는 정보를 한 파일 안에서 알 수 있게 됩니다.
근거: [Effective harnesses](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents) (initializer agent가 features를 "failing"으로 마킹해 조기 종료 방지)
→ **파일 추가 0개. 마크다운 관례만 변경.**

**A4. `dashboard.md` 재생성을 매 실험 → N회마다로 완화하거나 삭제 검토**
현재 프로토콜은 매 실험 후 전체 dashboard를 다시 씁니다. JSONL이 source of truth이므로 dashboard는 파생물입니다. 매 루프의 토큰/시간 비용이 실험 수에 선형으로 곱해집니다(스킬 자체가 "every second is multiplied by hundreds of runs"라고 경고하는 것과 같은 논리). 필요할 때 `jq`로 생성하는 편이 단순합니다.
근거: 스킬 내부 논리의 일관성 + JSONL이 source of truth라는 자체 선언. (외부 primary source 없음 — 판단 사항으로 표시)
→ **파일 1개 감소 가능.**

**A5. checkpointing/`/rewind`로 discard를 대체하려는 시도는 하지 말 것 (명시적 기각)**
문서화해 두면 향후 같은 논의를 반복하지 않습니다. 이유 세 가지: bash 변경 미추적, subagent edit 미복원, "Not a replacement for version control".
근거: [Checkpointing](https://code.claude.com/docs/en/checkpointing)
→ **변경 없음. 결정 기록.**

### B. 기능은 늘지만 복잡도도 늘어나는 옵션 (선택)

**B1. 최적화 대상이 단일 파일/커널/프롬프트/설정일 때는 GEPA `optimize_anything`으로 위임하는 분기 추가**
evaluator 함수 하나로 keep/discard·아카이브·reflection이 전부 라이브러리로 들어갑니다. `run.sh`가 이미 하는 일(컴파일/벤치마크 후 수치 + 에러 출력)이 GEPA evaluator + ASI와 1:1로 대응합니다. CUDA kernel 사례가 이 use case의 직접적 증거입니다.
비용: Python 의존성, candidate를 단일 artifact로 인코딩해야 함 → **다중 파일 repo 최적화에는 안 맞음.**
근거: [optimize_anything 소개 (2026-02-18)](https://gepa-ai.github.io/gepa/blog/2026/02/18/introducing-optimize-anything/), [gepa README](https://github.com/gepa-ai/gepa), [PyPI gepa 0.1.4](https://pypi.org/project/gepa/)

**B2. noisy metric 판정에 "텍스트 피드백"을 명시적 입력으로 승격**
현재 SKILL.md는 noise band와 N≥3 평균을 이미 요구합니다(좋음). 여기에 "실패 시 에러/프로파일 출력을 다음 실험 프롬프트에 반드시 포함"을 프로토콜로 못 박으면 GEPA의 ASI 개념을 라이브러리 없이 차용할 수 있습니다. Anthropic 가이드의 "something concrete to grade against"와도 통합니다.
근거: [optimize_anything](https://gepa-ai.github.io/gepa/blog/2026/02/18/introducing-optimize-anything/) (ASI = "the text-optimization analogue of a gradient"), [Harness design](https://www.anthropic.com/engineering/harness-design-long-running-apps)
비용: 프롬프트 길이 증가.

**B3. (권장하지 않음) OpenEvolve / ShinkaEvolve / MLflow / DVC / DSPy 도입**
모두 현재보다 moving parts가 많고, 대상 범위가 좁거나(single program / DSPy program) 문제의 절반만(추적만) 해결합니다. 사용자의 요구가 "더 단순하게"인 만큼 역방향입니다. 근거는 위 각 절.

### C. 검증하지 못한 항목 (정직한 공백)

- **Aim**: 문서 페이지 HTTP 429로 접근 실패. 미확인.
- **W&B 오프라인 모드**: FAQ 페이지에서 전문을 얻지 못함. 오프라인 모드 존재는 시사되나 인용 가능한 절차 미확보.
- **TextGrad, Optuna+LLM 하이브리드**: primary source 미확인.
- **벤더(OpenAI/Anthropic) eval+optimize 제품**: 임의 repo/임의 metric에 대응하는 first-party 제품 미발견.

---

## Sources

모두 2026-08-08 접근.

| # | 출처 | URL | 종류 | 날짜/버전 |
| --- | --- | --- | --- | --- |
| 1 | Anthropic — Effective harnesses for long-running agents | https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents | 1st-party blog | 2025-11-26 |
| 2 | Anthropic — Harness design for long-running application development | https://www.anthropic.com/engineering/harness-design-long-running-apps | 1st-party blog | 2026-03-24 |
| 3 | Claude Code Docs — Checkpointing | https://code.claude.com/docs/en/checkpointing | official docs | 현행 (v2.1.216+ 언급) |
| 4 | Claude Code Docs — Run Claude Code programmatically | https://code.claude.com/docs/en/headless | official docs | 현행 (v2.1.223 언급) |
| 5 | Geoffrey Huntley — Ralph Wiggum as a software engineer | https://ghuntley.com/ralph/ | 1st-party blog | 2025-07-14 |
| 6 | Geoffrey Huntley — everything is a ralph loop | https://ghuntley.com/loop/ | 1st-party blog | 2026-01-17 |
| 7 | GEPA — introducing optimize_anything | https://gepa-ai.github.io/gepa/blog/2026/02/18/introducing-optimize-anything/ | 1st-party docs/blog | 2026-02-18 |
| 8 | GEPA — repo README | https://github.com/gepa-ai/gepa | GitHub repo | 현행 |
| 9 | GEPA — `src/gepa/api.py` (optimize 시그니처) | https://github.com/gepa-ai/gepa/blob/main/src/gepa/api.py | source file | 현행 |
| 10 | GEPA — PyPI 릴리스 이력 | https://pypi.org/project/gepa/ | registry | 0.1.4 / 2026-07-15 |
| 11 | GEPA — arXiv | https://arxiv.org/abs/2507.19457 | paper | 2025-07 |
| 12 | DSPy — Choosing an optimizer | https://dspy.ai/diving-deeper/choosing-an-optimizer/ | official docs | 현행 |
| 13 | DSPy — GEPA optimization 튜토리얼 | https://dspy.ai/getting-started/gepa-optimization/ | official docs | 현행 |
| 14 | OpenEvolve — repo | https://github.com/codelion/openevolve | GitHub repo | v0.3.2 / 2026-07-18 |
| 15 | ShinkaEvolve — repo | https://github.com/SakanaAI/ShinkaEvolve | GitHub repo | push 2026-07-31, Apache-2.0 |
| 16 | AlphaEvolve results (코드 비공개 확인) | https://github.com/google-deepmind/alphaevolve_results | GitHub repo | 2025, arXiv:2506.13131 |
| 17 | MLflow — Tracking | https://mlflow.org/docs/latest/ml/tracking/ | official docs | MLflow 3 |
| 18 | DVC — Experiments overview | https://doc.dvc.org/user-guide/experiment-management/experiments-overview | official docs | 현행 |
| 19 | Git — git-notes | https://git-scm.com/docs/git-notes | official docs | 현행 |
