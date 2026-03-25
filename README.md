# bstack

AI 코딩 어시스턴트 툴킷 — Claude Code, OpenCode, 그 외.

## Features

bstack은 플러그인 형태로 묶인 단일 통합 패키지입니다:

- **Git Guard**: `--no-verify` 등 위험한 git 명령어 자동 차단
- **Session Handoff**: Claude 세션 간 컨텍스트 인계/인수
- **LSP Servers**: Bash, TypeScript, Python, Go, Kotlin, Lua, Nix, Terraform 언어 서버 자동 설치
- **Ralph Loop**: PRD 기반 자동 반복 개발 루프
- **Skills**: 개인 개발 워크플로우 스킬 모음
- **Jira Integration**: Jira 이슈 트리아지, 백로그 생성, 상태 리포트 등

## Quick Start

### Installation from GitHub

```bash
# Add this repository as a marketplace
claude plugin marketplace add https://github.com/baleen37/bstack

# Install the plugin
claude plugin install bstack
```

## Project Structure

```text
bstack/
├── plugins/
│   ├── me/                    # Core personal workflow plugin
│   │   ├── hooks/             # Session hooks (git guard, handoff, LSP checks)
│   │   └── skills/            # Personal skills (16 total)
│   ├── ralph/                 # Ralph Loop plugin
│   │   ├── hooks/             # Ralph persistence hooks
│   │   └── skills/            # ralph, ralph-cancel
│   ├── autoresearch/          # Autonomous experiment loop plugin
│   │   ├── commands/
│   │   ├── hooks/
│   │   └── skills/            # autoresearch
│   ├── jira/                  # Jira integration plugin
│   │   └── skills/            # 5 Jira workflow skills
│   ├── core/                  # Shared agent definitions
│   ├── lsp-*/                 # Individual LSP plugins (bash, go, lua, etc.)
├── scripts/                   # Utility scripts (handoff, dispatch, version sync)
├── docs/                      # Development and testing documentation
├── tests/                     # BATS tests
├── schemas/                   # JSON schemas
└── CLAUDE.md                  # Project instructions for Claude Code
```

### Skills

#### `me` plugin (personal workflow)

| Skill | Description |
|-------|-------------|
| `handoff` | 세션 종료 시 다음 세션을 위한 인계 문서 생성 |
| `pickup` | 이전 세션의 인계 문서 로드 |
| `create-pr` | 커밋, 푸시, PR 생성 통합 워크플로우 |
| `pr-pass` | CI 실패, 머지 충돌 등 깨진 PR 수정 |
| `commit` | Conventional Commits 형식으로 커밋 |
| `research` | 코드베이스 탐색 및 버그 조사 |
| `e2e` | 다수 컴포넌트에 걸친 E2E 검증 |
| `eval-harness` | 두 변형을 정의된 기준으로 비교 평가 |
| `iterate` | 반복 단일 변경 사이클로 점진적 개선 |
| `competitive-agents` | 병렬 경쟁 에이전트로 설계 탐색 |
| `tmux-workers` | tmux 분할 창에서 병렬 AI 에이전트 실행 |
| `claude-code-rules` | `.claude/rules/` 규칙 파일 생성/관리 |
| `remembering-conversations` | 이전 대화 컨텍스트 검색 및 적용 |
| `review-claudemd` | CLAUDE.md 개선사항 발굴 |
| `reddit-fetch` | WebFetch 차단 시 Reddit 콘텐츠 가져오기 |

#### `ralph` plugin

| Skill | Description |
|-------|-------------|
| `ralph` | PRD 기반 자동 반복 개발 루프 실행 |
| `ralph-cancel` | 실행 중인 Ralph 루프 취소 |

#### `autoresearch` plugin

| Skill | Description |
|-------|-------------|
| `autoresearch` | 최적화 목표를 위한 자율 실험 루프 실행 |

#### `jira` plugin

| Skill | Description |
|-------|-------------|
| `capture-tasks-from-meeting-notes` | 회의록에서 Jira 태스크 자동 생성 |
| `generate-status-report` | Jira 이슈 기반 프로젝트 상태 리포트 생성 |
| `search-company-knowledge` | Jira에서 내부 개념/프로세스 검색 |
| `triage-issue` | 버그 리포트 트리아지 및 중복 검색 |
| `spec-to-backlog` | Confluence 스펙 문서를 Jira 백로그로 변환 |

## Development

### Running Tests

```bash
# Run all BATS tests
bats tests/

# Run pre-commit hooks manually
pre-commit run --all-files
```

### Version Management & Release

이 프로젝트는 **semantic-release**와 **Conventional Commits**를 사용하여 자동으로 버전을 관리합니다.

```bash
# Interactive commit (recommended)
bun run commit

# Or write manually
git commit -m "type(scope): description"
```

**Types:**

- `feat`: New feature (minor version bump)
- `fix`: Bug fix (patch version bump)
- `docs`, `style`, `refactor`, `test`, `build`, `ci`, `chore`, `perf`: Patch version bump

#### Release Process

1. Push commits to main branch
2. GitHub Actions runs tests then semantic-release
3. Version is determined (feat → minor, fix → patch)
4. Root `plugin.json` and `marketplace.json` are updated
5. Git tag is created and GitHub release is published

## Pre-commit Hooks

```bash
pre-commit run --all-files
```

**Validations:**

- YAML syntax validation
- JSON schema validation
- ShellCheck (shell script linting)
- markdownlint (Markdown linting)
- commitlint (commit message format)

> Note: Pre-commit failures cannot be bypassed with `--no-verify` (enforced by git-guard).

## Contributing

1. **Conventional Commits** - Use `bun run commit` for interactive commit creation
2. **Pre-commit Hooks** - All hooks must pass before committing
3. **Test Coverage** - Add BATS tests for new features
4. **Documentation** - Update README.md for changes

## License

MIT License - see [LICENSE](LICENSE) file.
