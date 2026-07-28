# tmux Agent Status Hook 설계

## 목표

bstack의 `me` 플러그인이 Claude Code와 Codex의 공통 lifecycle event를
pane-local tmux 상태로 기록한다. Herdr, daemon, 상태 파일, 네트워크는 사용하지
않는다.

성공 조건:

- 같은 plugin hook이 Claude Code와 Codex에서 동작한다.
- tmux 안에서 실행된 agent만 현재 `TMUX_PANE`의 `@agent_status`를 변경한다.
- 같은 pane에서 새 session이 시작된 뒤 도착한 이전 session의 `SessionEnd`가
  새 상태를 지우지 않는다.
- tmux 밖의 agent와 tmux command 실패는 agent 실행을 방해하지 않는다.
- hook input의 prompt, cwd, message는 tmux command나 status text에 사용하지
  않는다.
- 기존 `me` hook과 Claude/Codex plugin packaging 검증이 유지된다.

## 상태 인터페이스

hook은 dotfiles와 다음 pane option contract를 공유한다.

| lifecycle event | `@agent_status` |
| --- | --- |
| `SessionStart` | `ready` |
| `UserPromptSubmit` | `running` |
| `PermissionRequest` | `needs_input` |
| `Stop` | `ready` |
| `SessionEnd` | option 해제 |

`@agent_status`는 dotfiles와 공유하는 공개 상태 계약이다. Hook은 pane의 현재
소유 session을 추적하기 위해 private pane option
`@agent_status_session_id`도 사용한다. Active event는 input의 `session_id`를
private option에 기록하면서 공개 상태를 갱신한다. `SessionEnd`는 input의
`session_id`가 현재 private option과 일치할 때만 두 option을 해제한다. 이
비교와 해제는 하나의 tmux `if-shell -F` command queue에서 수행한다.

Claude 전용 `Notification`과 `StopFailure`는 공용 `hooks.json`에 넣지 않는다.
Codex interactive TUI가 같은 실패 event를 제공하지 않기 때문이다. `PreToolUse`,
`PostToolUse`, subagent event도 main turn 상태에 필요한 최소 범위를 넘으므로
제외한다.

## 구성

### `plugins/me/hooks/agent-status.sh`

스크립트는 stdin JSON의 `hook_event_name`과 `session_id`를 `jq`로 읽는다.
Event는 위 고정 상태로 변환하고, session ID는 pane 소유권 판정에만 사용한다.

- `set -euo pipefail`을 사용한다.
- `TMUX_PANE`이 없거나 `tmux`가 PATH에 없으면 성공으로 종료한다.
- `session_id`가 없거나 빈 문자열이면 성공으로 종료한다.
- 알려진 active event는 한 tmux command sequence에서
  `@agent_status_session_id`와 `@agent_status`를 함께 설정한다.
- `SessionEnd`는 tmux `if-shell -F`에서 현재 `@agent_status_session_id`와
  input의 `session_id`를 비교하고, 일치할 때만 같은 command queue에서
  `@agent_status`와 `@agent_status_session_id`를 함께 해제한다.
- 성공적인 변경 뒤 `tmux refresh-client -S`를 시도한다.
- 잘못된 JSON, 알 수 없는 event, tmux command 실패는 hook consumer를
  중단시키지 않고 성공으로 종료한다.
- 공개 status option value는 고정 문자열이다. Hook input의 `session_id`만
  private owner option value로 전달하며 prompt, cwd, message는 사용하지 않는다.

### `plugins/me/hooks/hooks.json`

기존 `WorktreeCreate`와 `PreToolUse` 항목을 보존한다. 다섯 공통 lifecycle
event에 같은 command hook을 등록한다.

command path는 저장소 관례대로 다음 fallback을 사용한다.

```text
"${PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT}/hooks/agent-status.sh"
```

네 active event command의 timeout은 `5`, 빠른 정리가 필요한 `SessionEnd`의
timeout은 `3`이다. Plugin source에 포함된 `hooks/hooks.json`은 Claude와
Codex가 함께 자동 발견하므로 사용자 dotfiles에 provider별 hook 설정을
복제하지 않는다.

## 오류 처리와 한계

- side-effect 전용 UI hook이므로 실패는 coding agent turn을 차단하지 않는다.
- `SessionEnd`가 SIGKILL로 누락되면 pane option이 남을 수 있다. pane 종료 또는
  다음 lifecycle event가 정리하며 별도 watcher는 이번 범위에 추가하지 않는다.
- background subagent 상태는 main agent 상태와 합치지 않는다.
- Codex에서는 새 plugin hook definition에 대해 `/hooks` trust 확인이 필요할 수
  있다.

## 테스트

`tests/me/agent-status.bats`가 fake `tmux` executable과 실제 hook script를
사용해 다음 동작을 검증한다.

- 각 공통 event의 정확한 `set-option` argument
- 소유자가 일치하는 `SessionEnd`의 두 pane option 해제
- A start, B prompt, 늦은 A end 순서에서 B의 owner와 `running` 상태가
  유지되고 B end에서 두 option이 해제되는 race 회귀
- `TMUX_PANE` 미설정과 tmux 부재 시 no-op
- 잘못된 JSON, 알 수 없는 event, 없거나 빈 `session_id`의 no-op
- tmux 실패가 hook exit code에 전파되지 않음
- `hooks.json`의 다섯 event, event별 timeout, portable plugin-root command

검증은 focused BATS, ShellCheck, Codex artifact drift check, 전체 BATS,
pre-commit 순서로 실행한다. 버전 파일은 semantic-release가 관리하므로 직접
수정하지 않는다.
