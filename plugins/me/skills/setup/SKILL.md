---
name: setup
description: Use when setting up Claude Code global configuration on a new machine — CLAUDE.md, settings.json, statusline.sh
---

# Global Setup

새 머신에서 Claude Code 글로벌 설정을 구성하는 체크리스트.

이 스킬 디렉토리에 실제 설정 파일들이 포함되어 있다:

| 파일 | 대상 경로 | 역할 |
|------|----------|------|
| `CLAUDE.md` | `~/.claude/CLAUDE.md` | 전역 행동 지침 |
| `settings.json` | `~/.claude/settings.json` | 권한, 플러그인, 상태바 설정 |
| `statusline.sh` | `~/.claude/statusline.sh` | 상태바 스크립트 |

## How to Use

1. 이 스킬의 파일들을 `~/.claude/`로 복사
2. `statusline.sh` 실행 권한 부여
3. `~/.claude/local.md` 생성 (머신별 오버라이드)
4. `claude` 재시작

```bash
SKILL_DIR="$(dirname "$0")"  # 또는 캐시 경로

cp "$SKILL_DIR/CLAUDE.md" ~/.claude/CLAUDE.md
cp "$SKILL_DIR/settings.json" ~/.claude/settings.json
cp "$SKILL_DIR/statusline.sh" ~/.claude/statusline.sh
chmod +x ~/.claude/statusline.sh
touch ~/.claude/local.md
```

## Checklist

### CLAUDE.md
- [ ] Karpathy Guidelines 포함
- [ ] `## Language` 섹션 (응답 언어)
- [ ] `@local.md` include 존재
- [ ] `~/.claude/local.md` 파일 존재 (없으면 `touch`)

### settings.json
- [ ] `permissions.allow` 필수 도구 포함 (`Bash`, `Read`, `Edit`, `Write`, `Glob`, `Grep` 등)
- [ ] `statusLine.command` → `bash ~/.claude/statusline.sh`
- [ ] `enabledPlugins` — bstack, superpowers 활성화
- [ ] `extraKnownMarketplaces` — bstack marketplace 등록

### statusline.sh
- [ ] 실행 권한: `chmod +x ~/.claude/statusline.sh`
- [ ] `settings.json`의 `statusLine.command` 경로와 일치

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
