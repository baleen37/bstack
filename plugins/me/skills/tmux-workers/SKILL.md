---
name: tmux-workers
description: Use when you need to run multiple AI CLI agents (claude, codex, gemini) in parallel on independent subtasks — spawns visible tmux split panes for real-time monitoring
---

# tmux-workers

## Overview

tmux split pane에서 AI CLI 에이전트를 fire-and-forget으로 실행한다. task file 패턴으로 특수문자를 안전하게 전달하고, pane에서 실시간으로 출력을 볼 수 있다.

## When to Use

- 독립적인 서브태스크 2개 이상을 병렬로 돌릴 때
- 코드 분석, 리팩터링, 테스트 작성 등을 여러 에이전트에 분배할 때
- 결과를 직접 수집할 필요 없이 fire-and-forget으로 충분할 때

**Don't use when:**
- 순차 의존성이 있는 태스크 (A 결과가 B 입력)
- 단일 태스크 — 그냥 직접 하면 됨
- tmux 세션 밖에서 실행 중일 때

## Spawn Pattern

```bash
# 1. Task file 작성 (특수문자 안전)
ID="worker-$(date +%s)-$$"
TASK_FILE="/tmp/${ID}.txt"
printf '%s' "$TASK" > "$TASK_FILE"

# 2. Split pane 생성 + pane ID 캡처
PANE_ID=$(tmux split-window -c "$CWD" -PF '#{pane_id}' 'bash')

# 3. 명령 전송
tmux send-keys -t "$PANE_ID" \
  "cat '$TASK_FILE' | claude -p --permission-mode bypassPermissions; rm -f '$TASK_FILE'" Enter
```

추가 워커도 동일하게 `tmux split-window`로 생성. 레이아웃은 tmux 기본에 맡긴다.

## Agent Commands

| Agent | Command |
|-------|---------|
| claude | `cat "$TASK_FILE" \| claude -p --permission-mode bypassPermissions` |
| codex | `codex exec --full-auto - < "$TASK_FILE"` |
| gemini | `gemini -p '' --yolo < "$TASK_FILE"` |

## Useful Claude Flags

| Flag | Purpose |
|------|---------|
| `--max-turns N` | 무한루프 방지 |
| `--model opus` | 모델 지정 |
| `--output-format json` | 구조화된 결과 (cost, duration 포함) |
| `--append-system-prompt "..."` | 추가 지시사항 |
| `--add-dir ../other` | 추가 작업 디렉토리 |
| `--plugin-dir path` | 플러그인 로드 (스킬, 훅 등) |

## Quick Reference

```bash
# 단일 워커
TASK_FILE="/tmp/worker-$(date +%s)-$$.txt"
printf '%s' "Fix lint errors in src/" > "$TASK_FILE"
PANE=$(tmux split-window -c "$(pwd)" -PF '#{pane_id}' 'bash')
tmux send-keys -t "$PANE" "cat '$TASK_FILE' | claude -p --permission-mode bypassPermissions --max-turns 10; rm -f '$TASK_FILE'" Enter

# 여러 워커
for i in 1 2 3; do
  TF="/tmp/worker-$(date +%s)-$$-${i}.txt"
  printf '%s' "Task $i content" > "$TF"
  P=$(tmux split-window -c "$(pwd)" -PF '#{pane_id}' 'bash')
  tmux send-keys -t "$P" "cat '$TF' | claude -p --permission-mode bypassPermissions; rm -f '$TF'" Enter
done
```

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| 프롬프트를 인라인으로 전달 | task file 사용 — `"`, `'`, `$`, `&` 등이 깨짐 |
| `--dangerously-skip-permissions` 사용 | `--permission-mode bypassPermissions` 가 현재 정식 플래그 |
| 결과 수집을 위해 blocking | fire-and-forget. 결과가 필요하면 `--output-format json > file` |
| tmux 밖에서 실행 | `$TMUX` 변수로 먼저 확인 |
