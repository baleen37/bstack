# /me:evolve — Transcript 기반 Skill·Doc 진화 도구

## 배경

Claude Code 세션을 한참 돌리고 나면 같은 실수·우회·교정이 반복된다. Geoffrey Huntley의 Ralph Loop 글에서 지적하듯, 이런 실패 신호는 다음 반복 때 프롬프트·규칙 파일에 "인코딩"되어야 더 이상 반복되지 않는다. Huntley는 이걸 사람이 직접 `PROMPT_build.md` / `AGENTS.md`를 손으로 고치며 처리하지만, 그 작업은:

- 어떤 신호가 있었는지 찾기 위해 transcript를 직접 뒤지는 비용이 큼
- 어떤 파일을 고쳐야 할지 매번 판단해야 함
- 시간이 지나면 잊혀짐

`/me:evolve`는 이 수동 진화 단계를 **반자동화**한다. 자동으로 신호를 추출하고 어디를 어떻게 고치자고 제안하되, 적용은 사람이 한 건씩 승인한다.

## 합의된 원칙

- 진화 단계의 자동화 수준은 **L2(제안 + 승인 후 적용)**. 자동 commit/push 안 함, 신호 검출도 안 함, 한 건씩 명시 승인.
- 분석 입력은 **세션 transcript 파일** (`~/.claude/projects/<encoded-cwd>/<session-id>.jsonl`). 외부 메모리·로그 안 봄.
- 수정 대상은 **로컬 git 추적 파일만**. 외부 플러그인 캐시는 수정 차단, 별도 upstream 제안 파일에만 남김.
- **회고 보고서는 안 만든다**. 신호와 제안을 콘솔에 즉시 출력하고 한 건씩 처리. 부산물 최소화.
- 트레이서빌리티는 **commit 메시지**에서만 보장 (신호 인용 + 적용된 변경).

## 접근법

**A안 (선택됨): 신호 추출 → 콘솔 출력 → 한 건씩 승인 + 개별 commit**

기존 `me:handoff`, `me:pickup`과 동일한 "수동 트리거 / write-oriented" 패턴. 보고서 같은 중간 산출물 없음.

검토 후 채택하지 않은 안:
- B (보고서 + 일괄 적용): 보고서가 잡파일로 쌓이고 사용자가 안 읽음. 두 번 일하는 느낌.
- C (Huntley 스타일 자동 commit + git reset 롤백): 변경 단위가 너무 크면 부분 롤백이 어려움. 한 건씩 개별 commit이 더 안전.
- D (서브에이전트 전면 분석): 비싸고 hallucination 위험. transcript 통째 읽히기 전에 신호 구간만 좁히는 게 합리적.

## 사용법

```
/me:evolve                          현재 세션 회고
/me:evolve me:research              해당 스킬에 집중해 최근 세션 분석
/me:evolve --session <id>           특정 세션 ID 회고
/me:evolve --since 7d me:browse     7일치 + 스킬 필터
/me:evolve --dry-run                제안만 보고 적용 안 함
```

기본값(인자 없음)은 현재 세션. 인자에 스킬명이 있으면 해당 스킬이 등장한 세션·구간으로 좁힌다.

## 입력

- 위치: `~/.claude/projects/<encoded-cwd>/<session-id>.jsonl`
  - encoded-cwd = 현재 cwd의 `/`를 `-`로 치환한 디렉토리명
- 한 줄 한 JSON. `type` 필드로 구분: `user` / `assistant` / `system` / `attachment` / `mode` 등
- 분석 대상은 `user` / `assistant`만. 나머지는 무시
  - 그중에서도 `type=="user"` & content가 `string` 또는 `[{type:"text"}]` 인 것만 **실제 사용자 발화**
  - `[{type:"tool_result"}]`는 도구 출력이므로 분석에 안 씀
- transcript가 200턴 이상이면 시작 시 사용자에게 범위 좁히기 권유 (`--since` 등 인자 안내)

## 신호 추출

세 가지 신호만 수집한다. 그 외는 노이즈로 판단.

### A. 사용자 교정/중단

- 사용자 발화 중 다음 패턴:
  - 부정/방향 전환: "아니", "그게 아니고", "그러지 말고", "다시", "no", "stop", "wait", "hold on"
  - 직접 정정: "그게 아니라 X 해줘", "X 봐"
  - 직접 참조 정정: `@<path>` 형태로 경로를 다시 지정하는 메시지
- assistant 메시지에 `"interrupted"` 표시가 붙은 직전 행동
- 각 교정 발화는 **컨텍스트(직전 assistant 행동 1~2개)** 와 함께 묶어서 보관

### B. 장황한 탐색

- 같은 디렉토리/파일을 3회 이상 반복 Read
- 동일 명령(grep / find / ls)을 미세하게 다른 인자로 3회 이상 반복
- 한 가지 정보를 얻기까지 5개 이상의 tool_use가 소비된 구간
- ToolSearch → 같은 도구를 다시 찾는 패턴

### C. 성공 패턴 강화 후보

- 사용자가 명시적으로 긍정한 직후의 행동 ("좋아", "perfect", "그렇지", "yes", "ok")
- 어떤 스킬을 호출한 직후 짧은 구간에서 사용자 긍정으로 끝난 흐름

## 분석 대상 파일 판단 (어디를 고칠 후보로 보는가)

신호 → 후보 파일 매핑:

| 신호 패턴 | 1순위 후보 | 2순위 |
|---|---|---|
| "이 스킬 안 쓰네" / 스킬 미발견 | 해당 SKILL.md (description, 트리거 키워드) | 가까운 AGENTS.md |
| 스킬 invoke 후에도 규칙 위반 | 해당 SKILL.md (본문, Red Flags 섹션) | — |
| 장황한 탐색 + 결국 X를 찾음 | 가까운 AGENTS.md (Key Files / Subdirectories) | CLAUDE.md |
| 프로젝트 룰/관례 위반 | 가까운 CLAUDE.md | AGENTS.md |
| 성공 패턴 | 자주 호출된 SKILL.md | — |

**경계**:
- 외부 플러그인 캐시(`~/.claude/plugins/cache/...`) 경로의 파일은 직접 수정 차단
  - 캐시 변경 제안이 발생하면 그 한 건만 `docs/superpowers/evolutions/YYYY-MM-DD-upstream-suggestions.md`에 누적 저장
- git 추적 안 되는 파일은 사용자 확인부터
- 새 스킬 생성은 이 도구 범위 밖 (별도 `writing-skills` 영역)

## 결과물

회고 보고서는 만들지 않는다. 다음만 발생:

1. **콘솔 출력** — 발견된 신호와 제안을 즉시 출력, 한 건씩 승인 받음
2. **Edit 적용** — 승인된 제안은 해당 파일을 그 자리에서 수정
3. **개별 git commit** — 제안 한 건당 별도 commit
   - 메시지 형식:
     ```
     evolve(<scope>): <한 줄 요약>

     Signal: <신호 한 줄 인용>
     Session: <session-id>
     ```
4. **upstream-only 파일** (해당하는 경우에만) — 외부 캐시 경로 변경 제안이 있을 때만 누적

## 적용 흐름

```
1. 시작 가드
   - git status가 dirty면 거부 ("커밋이나 stash 먼저 하세요")
   - 분석할 transcript 결정 (인자 파싱)
   - 200턴 이상이면 범위 좁히기 권유

2. 신호 추출
   - transcript 한 번 훑어 A/B/C 신호 수집
   - 각 신호에 ID 부여 (S1, S2, ...)

3. 후보 파일 매핑
   - 신호별로 위 표에 따라 후보 파일 결정
   - 외부 캐시는 upstream-only로 분류

4. 제안 생성 + 적용 루프
   - 신호 1건 → 후보 파일 + 정확한 patch 제시
   - 콘솔 출력:
       S1. 사용자 교정 "그 파일 아니야"
         직전 행동: grep -r foo src/
         → P1 제안: plugins/me/skills/browse/SKILL.md description 강화
         [patch diff 미리보기]
         적용할까요? [y/n/skip/edit]
   - y: Edit + 개별 commit
   - edit: 사용자가 patch를 즉석 수정 후 적용
   - skip / n: 다음으로
   - 다음 제안...

5. 마무리
   - upstream-only 항목이 있으면 누적 파일에 추가하고 경로 출력
   - 적용된 commit 목록을 요약 출력
```

## 안전 가드

- **외부 캐시 차단**: 경로가 `~/.claude/plugins/cache/`로 시작하면 Edit 시도 자체를 차단
- **dirty tree 차단**: 시작 시점 `git status` 검사
- **dry-run**: `--dry-run` 인자로 적용 없이 제안만 출력
- **개별 commit**: 변경 한 건당 commit → `git revert <sha>` 한 줄로 개별 롤백
- **patch 미리보기 강제**: 사용자가 y를 누르기 전에 diff가 반드시 표시됨

## 비범위

- transcript 자체 수집·저장 (Claude Code가 이미 함)
- 새 스킬 생성 (`writing-skills` 영역)
- 자동 트리거 (SessionEnd hook 등 — 명시적으로 수동만)
- 여러 세션 자동 병합 분석 (1순위는 단일 세션, 다중 세션은 인자로 좁힌 경우만)
- 수정 결과를 다른 사람과 공유 (그건 PR 단계에서 따로)
