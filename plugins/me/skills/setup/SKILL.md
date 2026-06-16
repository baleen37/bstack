---
name: setup
description: Use when setting up Claude Code global configuration on a new machine — CLAUDE.md, settings.json, statusline.sh, worktree configuration
---

# Global Setup

새 머신에서 Claude Code 글로벌 설정을 구성하는 체크리스트.

이 스킬 디렉토리에 실제 설정 파일들이 포함되어 있다:

| 파일 | 대상 경로 | 역할 |
| --- | --- | --- |
| `CLAUDE.md` | `${CLAUDE_HOME:-~/.claude}/CLAUDE.md` | 전역 행동 지침 |
| `AGENTS.md` | `${CODEX_HOME:-~/.codex}/AGENTS.md` | Codex 전역 행동 지침 (`CLAUDE.md` symlink) |
| `settings.json` | `${CLAUDE_HOME:-~/.claude}/settings.json` | 권한, 플러그인, 상태바 설정 |
| `statusline.sh` | `${CLAUDE_HOME:-~/.claude}/statusline.sh` | 상태바 스크립트 |
| `setup-worktree.sh` | (WorktreeCreate 훅에서 자동 실행) | 워크트리 초기화 |

## How to Use

1. 이 스킬의 파일들을 현재 실행 환경의 Claude/Codex 설정 경로에 적용
2. `statusline.sh` 실행 권한 부여
3. `~/.claude/local.md` 생성 (머신별 오버라이드)
4. `claude` 재시작

```bash
SKILL_DIR="$(dirname "$0")"  # 또는 캐시 경로
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"

mkdir -p "$CLAUDE_HOME" "$CODEX_HOME"
cp "$SKILL_DIR/CLAUDE.md" "$CLAUDE_HOME/CLAUDE.md"
cp "$SKILL_DIR/settings.json" "$CLAUDE_HOME/settings.json"
cp "$SKILL_DIR/statusline.sh" "$CLAUDE_HOME/statusline.sh"
ln -sf "$SKILL_DIR/AGENTS.md" "$CODEX_HOME/AGENTS.md"
chmod +x "$CLAUDE_HOME/statusline.sh"
touch "$CLAUDE_HOME/local.md"
```

## Checklist

### CLAUDE.md

- [ ] Karpathy Guidelines 포함
- [ ] `## Language` 섹션 (응답 언어)
- [ ] `@local.md` include 존재
- [ ] `${CLAUDE_HOME:-~/.claude}/local.md` 파일 존재 (없으면 `touch`)

### AGENTS.md

- [ ] setup 원본 `AGENTS.md`는 `CLAUDE.md` symlink
- [ ] `${CODEX_HOME:-~/.codex}/AGENTS.md`는 setup 원본 `AGENTS.md`로 symlink

### settings.json

- [ ] `permissions.allow` 필수 도구 포함 (`Bash`, `Read`, `Edit`, `Write`, `Glob`, `Grep` 등)
- [ ] `statusLine.command` → `bash ~/.claude/statusline.sh`
- [ ] `enabledPlugins` — bstack, superpowers 활성화
- [ ] `extraKnownMarketplaces` — bstack marketplace 등록

### statusline.sh

- [ ] 실행 권한: `chmod +x ~/.claude/statusline.sh`
- [ ] `settings.json`의 `statusLine.command` 경로와 일치

### Worktree

- [ ] `WorktreeCreate` 훅이 `setup-worktree.sh`를 가리킴 (bstack 플러그인에서 관리)
- [ ] `.worktrees/` 디렉토리가 `.gitignore`에 포함됨

## settings.json 주요 섹션

**statusLine:**

```json
"statusLine": {
  "type": "command",
  "command": "bash ~/.claude/statusline.sh"
}
```

**bstack marketplace:**

```json
"extraKnownMarketplaces": {
  "bstack": {
    "source": {
      "source": "github",
      "repo": "baleen37/bstack"
    },
    "autoUpdate": true
  }
}
```
