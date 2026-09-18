# Spec: autoresearch 독립 plugin 복원

- **작성일**: 2026-05-31
- **상태**: design
- **관련 브랜치**: tidy-nebula-sagan

## 배경

현재 autoresearch는 `plugins/me/skills/autoresearch/SKILL.md`로 통합되어(#660), 턴 간 자동 진행과
종료를 Claude Code 빌트인 `/goal` 명령에 위임한다. 그러나 **`/goal`은 사용자만 프롬프트에 직접
타이핑할 수 있는 세션 명령어**이고, Claude(에이전트)는 이를 실행할 수단이 없다. SKILL.md Flow 6번이
Claude에게 `/goal "..."`을 "자동 설정"하라고 지시하기 때문에, Claude는 유일한 명령 실행 수단인 Bash로
시도하고 `Exit code 127: no such file or directory: /goal`로 실패한다.

### 검증 (이번 세션에서 확인한 사실)

- 설치된 Claude Code: **2.1.158** (>= 2.1.139, `/goal` 요구 버전 충족)
- 바이너리에 `/goal` 실재 확인 (`"goal clear"`, `"session-scoped"`, `"Set a goal"`, `/goal is only available in trusted workspaces` 등 UI 문자열 — 모두 **사용자 안내용**, 에이전트 API 아님)
- trust 수락됨, `disableAllHooks`/`allowManagedHooksOnly` 미설정 — 전제 조건 모두 충족
- **재현 완료**: `/goal "..."`를 Bash로 실행 → `Exit code 127: no such file or directory: /goal`

즉 환경 결함이 아니라 **SKILL.md가 에이전트에게 사용자 전용 명령어를 실행하라고 지시한 설계 결함**이다.

## 목표

`/goal` 의존이 없던 **옛 독립 `plugins/autoresearch/` plugin을 그대로 복원**하여 `/goal` 실행 불가
문제를 원천 제거한다. 옛 plugin은 `UserPromptSubmit` hook으로 턴마다 "NEVER STOP" 컨텍스트를 주입하는
방식이라 `/goal`을 쓰지 않는다.

## 의도된 트레이드오프 (사용자 승인됨)

옛 `UserPromptSubmit` hook 방식은 **턴을 자동으로 시작시키지 않는다.** 사용자가 메시지를 보낼 때마다
hook이 "loop forever" 리마인더를 주입할 뿐이라, 사용자 입력이 없으면 루프가 멈춘다. 이는 #660 설계
문서가 "진짜 autonomous loop 아님"이라며 기각했던 한계다. 사용자는 이 트레이드오프를 인지하고 복원을
선택했다 — `/goal` 깨짐 제거와 매 실험 직접 steer 가능이라는 이점을 우선한다.

## 설계

### 복원 대상 (`efa9cdf4~1`에서 추출)

```
plugins/autoresearch/
├── .claude-plugin/plugin.json        # name=autoresearch, repository=obra/autoresearch-claude-code
├── .codex-plugin/plugin.json         # 위 + "skills": "./skills/"
├── commands/autoresearch.md          # /autoresearch [off | goal] 명령
├── hooks/hooks.json                  # UserPromptSubmit → autoresearch-context.sh 등록
├── hooks/autoresearch-context.sh     # .autoresearch/autoresearch.md 있고 off 없으면 NEVER STOP 주입
└── skills/autoresearch/SKILL.md      # /goal 없는 hook 기반 버전 (253줄)
```

**버전 정합성**: 옛 plugin.json 두 개의 `version`은 `17.11.2`였다. 현재 다른 plugin들은 모두
`17.16.2`이므로, 복원 시 **두 plugin.json의 version을 `17.16.2`로 맞춘다** (semantic-release 정합성).

### 제거 대상 (#660이 추가한 것)

| 항목 | 처리 |
|------|------|
| `plugins/me/skills/autoresearch/SKILL.md` | 삭제 |
| me plugin 문서의 autoresearch 스킬 행 | 제거 (README/AGENTS/CLAUDE.md에 있으면) |

### marketplace.json

`plugins` 배열에 autoresearch 항목 추가 (현재 4개 → 5개):

```json
{
  "name": "autoresearch",
  "description": "Autonomous experiment loop — iteratively optimize any metric with git-tracked experiments",
  "source": "./plugins/autoresearch",
  "category": "development",
  "tags": ["experiments", "optimization", "autonomous", "research"],
  "version": "17.16.2"
}
```

### 복원 방식: revert가 아닌 수동 추출

`git revert efa9cdf4`는 **금지**. 이유: #660 이후 release 커밋들(17.12.0~17.16.2)이 marketplace.json을
계속 수정해 revert 시 충돌한다. 대신 `git show efa9cdf4~1:<path>`로 옛 파일을 추출해 복원하고,
marketplace.json/버전은 현재 상태에 맞춰 수동 편집한다.

## 동작 방식 (복원 후)

1. `/autoresearch <goal>` → fresh start: 스킬이 setup, baseline, 첫 실험까지 진행
2. 사용자가 메시지를 보낼 때마다 `UserPromptSubmit` hook이 `.autoresearch/autoresearch.md` 존재 +
   `.autoresearch/off` 부재를 확인하고 "NEVER STOP, loop forever" 컨텍스트 주입 → 다음 실험 진행
3. `/autoresearch off` → `.autoresearch/off` sentinel 생성으로 일시정지
4. `/goal` 일절 미사용 → Bash 실행 실패 문제 소멸

## 비목표

- SKILL.md 본문 개선 (G1/G2 등 리서치에서 식별한 결함 수정) — 별도 작업
- JSONL/dashboard/worklog/ideas 포맷 변경
- Stop 스크립트 훅 도입 (이번엔 옛 plugin 그대로 복원)

## 리스크

| 리스크 | 완화 |
|--------|------|
| 스킬 이름 충돌 (me/autoresearch 잔존) | me 쪽 SKILL.md 삭제로 제거 |
| 버전 불일치로 semantic-release 깨짐 | 두 plugin.json version을 17.16.2로 통일 |
| hook 스크립트 실행권한 누락 | 복원 후 `chmod +x hooks/autoresearch-context.sh` |
| marketplace JSON 문법 오류 | 복원 후 `jq . marketplace.json` 검증 |

## 성공 기준

- `plugins/autoresearch/` 6개 파일 복원, hook 스크립트 실행권한 있음
- `plugins/me/skills/autoresearch/` 제거됨
- marketplace.json에 autoresearch 항목 존재, `jq`로 유효
- 두 plugin.json version = 17.16.2
- `/goal` 참조가 복원된 plugin 어디에도 없음 (옛 SKILL.md는 hook 기반)
- pre-commit / 관련 bats 통과

## 참고

- 옛 plugin 출처: [obra/autoresearch-claude-code](https://github.com/obra/autoresearch-claude-code)
- 통합 커밋: `efa9cdf4` (#660), 직전 상태: `efa9cdf4~1`
- /goal 문서: https://code.claude.com/docs/en/goal
