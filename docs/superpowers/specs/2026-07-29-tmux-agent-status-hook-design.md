# tmux Agent Status Hook 설계

## 목표

bstack의 `me` 플러그인이 Claude Code와 Codex의 공통 lifecycle event를
pane-local tmux 상태로 기록한다. Herdr, daemon, 상태 파일, 네트워크는 사용하지
않는다.

성공 조건:

- 같은 plugin hook이 Claude Code와 Codex에서 동작한다.
- tmux 안에서 실행된 agent만 현재 `TMUX_PANE`의 `@agent_status`를 변경한다.
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

Claude 전용 `Notification`과 `StopFailure`는 공용 `hooks.json`에 넣지 않는다.
Codex interactive TUI가 같은 실패 event를 제공하지 않기 때문이다. `PreToolUse`,
`PostToolUse`, subagent event도 main turn 상태에 필요한 최소 범위를 넘으므로
제외한다.

## 구성

### `plugins/me/hooks/agent-status.sh`

스크립트는 stdin JSON의 `hook_event_name`만 `jq`로 읽고 위 고정 상태로
변환한다.

- `set -euo pipefail`을 사용한다.
- `TMUX_PANE`이 없거나 `tmux`가 PATH에 없으면 성공으로 종료한다.
- 알려진 active event는
  `tmux set-option -p -t "$TMUX_PANE" @agent_status "$state"`를 실행한다.
- `SessionEnd`는
  `tmux set-option -pu -t "$TMUX_PANE" @agent_status`를 실행한다.
- 성공적인 변경 뒤 `tmux refresh-client -S`를 시도한다.
- 잘못된 JSON, 알 수 없는 event, tmux command 실패는 hook consumer를
  중단시키지 않고 성공으로 종료한다.
- option value는 고정 문자열이며 hook input을 shell argument로 전달하지 않는다.

### `plugins/me/hooks/hooks.json`

기존 `WorktreeCreate`와 `PreToolUse` 항목을 보존한다. 다섯 공통 lifecycle
event에 같은 command hook을 등록한다.

command path는 저장소 관례대로 다음 fallback을 사용한다.

```text
"${PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT}/hooks/agent-status.sh"
```

각 command에는 짧은 timeout을 둔다. Plugin source에 포함된 `hooks/hooks.json`은
Claude와 Codex가 함께 자동 발견하므로 사용자 dotfiles에 provider별 hook 설정을
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
- `SessionEnd`의 pane option 해제
- `TMUX_PANE` 미설정과 tmux 부재 시 no-op
- 잘못된 JSON과 알 수 없는 event의 no-op
- tmux 실패가 hook exit code에 전파되지 않음
- `hooks.json`의 다섯 event와 portable plugin-root command

검증은 focused BATS, ShellCheck, Codex artifact drift check, 전체 BATS,
pre-commit 순서로 실행한다. 버전 파일은 semantic-release가 관리하므로 직접
수정하지 않는다.
