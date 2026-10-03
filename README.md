# bstack

An AI coding assistant toolkit. It is designed for both Claude Code and Codex,
and bundles personal workflow automation, safer Git operations, session handoff, LSP installation, and external tool integrations.

## Highlights

- Git protection: blocks dangerous commands such as `--no-verify`
- Session handoff: carries work context into the next session
- LSP auto-installation: Bash, TypeScript, Python, Go, Kotlin, Lua, Nix, Terraform
- Iterative development loop: PRD-driven automated improvement cycles
- Personal skills: commit, review, research, PR creation, E2E verification
- External integrations: Slack, Atlassian, Datadog

## 설치

Install directly from the GitHub marketplace.

```bash
claude plugin marketplace add https://github.com/baleen37/bstack
claude plugin install me@bstack
```

## Codex 호환성

This repository treats Claude Code metadata as the source of truth and generates Codex artifacts from it.

- Source of truth: `.claude-plugin/marketplace.json`, `plugins/*/.claude-plugin/plugin.json`
- Generated artifacts: `.agents/plugins/marketplace.json`, `plugins/*/.codex-plugin/plugin.json`
- Shared assets: `plugins/*/skills/**`
- Do not edit generated Codex files directly; regenerate them with `bun run sync:codex`

```bash
bun run sync:codex
```

## Plugins

| Plugin | Purpose |
| --- | --- |
| `me` | Unified design, plan, execution, TDD, debugging, review, verification, PRs, and shipping (41 skills) |
| `slack` | Slack message, thread, channel, and user search |
| `atlassian` | Jira work guidance through `twg` |
| `datadog` | Logs, monitors, APM, and metric investigation |
| `autoresearch` | Automated experiment loop driven by metrics |

## 기본 개발 흐름

`me:brainstorming` → `me:writing-plans` → `me:executing-plans` 또는
`me:subagent-driven-development` → `me:verify` → `me:code-review` → `me:create-pr`.

작은 변경은 brainstorming에서 짧은 설계를 승인받고 바로 구현합니다.
여러 단계의 작업은 작성한 스펙과 계획을 검토하고 실행 방법을 선택합니다.
실제 리뷰는 `me:code-review`, 리뷰 요청과 피드백 처리는 각각
`me:requesting-code-review`, `me:receiving-code-review`가 담당합니다.

큰 불확실성이 있을 때만 `me:wayfinder` → `me:writing-spec` → 스펙 검토 →
`me:writing-plans`로 진입합니다. 스펙 기본 위치는 `docs/specs/`입니다.
tracker 게시와 `me:to-tickets`는 선택 기능이며, 구현 계획과 별개의 실행
그래프를 자동 생성하지 않습니다. 일반 설계·구현에는 tracker 설정이 필요 없습니다.

전체 기능과 선택 경로는 [me README](plugins/me/README.md)를 참고하세요.

## 설치 전환

이 통합 버전이 배포된 뒤 기존 `superpower`, `mattpocock-skills`를 제거하고
`me`를 갱신하세요. 기존 namespace 별칭은 제공하지 않습니다.
아래 예시는 marketplace 이름이 `bstack`, 설치 scope가 `user`인 경우입니다.
`baleen-marketplace`로 설치했다면 이름을 바꾸고, 다른 scope라면 맞춰 실행하세요.

Claude Code:

```bash
claude plugin uninstall superpower@bstack --scope user --keep-data
claude plugin uninstall mattpocock-skills@bstack --scope user --keep-data
claude plugin marketplace update bstack
claude plugin update me@bstack --scope user
```

Codex:

```bash
codex plugin remove superpower@bstack
codex plugin remove mattpocock-skills@bstack
codex plugin marketplace upgrade bstack
codex plugin add me@bstack
```

설치하지 않은 기존 플러그인의 제거 명령은 생략하세요. 갱신 후 새 세션을 열어
`me:ask`와 `me:using-me`가 발견되는지 확인하세요. 과거 설계·계획 문서는
당시 기록으로 유지하며, 진행 중인 과거 계획은 실행 전에 현재 `me:` 호출로 맞추세요.

## Project Structure

```text
bstack/
├── plugins/              # Plugin sources
│   ├── me/               # Personal workflow plugin
│   ├── slack/            # Slack integration
│   ├── atlassian/        # Jira guidance through twg
│   ├── datadog/          # Datadog integration
│   └── autoresearch/     # Automated experiment loop
├── scripts/              # Sync and utility scripts
├── tests/                # BATS tests
├── schemas/              # JSON schemas
└── CLAUDE.md             # Project guidance for AI agents
```

## Development

### Testing

```bash
bun run test
pre-commit run --all-files
```

### Codex 아티팩트 확인

```bash
bun run check:codex
```

### Commits

This repository uses Conventional Commits and semantic-release.

```bash
bun run commit
git commit -m "type(scope): description"
```

## Release

Releases are automated.

1. Push commits to the `main` branch.
2. GitHub Actions runs the tests.
3. semantic-release determines the version.
4. `.claude-plugin/marketplace.json` and each `plugins/*/.claude-plugin/plugin.json` are synchronized.
5. A Git tag and GitHub Release are created.

## Pre-commit

Pre-commit hooks validate:

- YAML syntax
- JSON schema
- ShellCheck
- markdownlint
- commitlint

`git guard` blocks `--no-verify` bypasses, so the hooks cannot be skipped.

## Contributing

1. Use Conventional Commits.
2. After changes, run `bun run test` and `pre-commit run --all-files`.
3. Add BATS tests for new functionality.
4. Update `README.md` when documentation changes.

## License

MIT License. See [LICENSE](LICENSE) for details.
