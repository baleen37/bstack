# notion

Notion workspace guidance powered by the official [`ntn`](https://developers.notion.com/cli/get-started/overview) CLI.

This plugin is intentionally MCP-free.

## Installation

Recommended on macOS and Linux:

```bash
curl -fsSL https://ntn.dev | bash
ntn --version
```

Alternative installation methods:

```bash
npm install --global ntn
```

The npm installation requires Node.js 22+ and npm 10+. On Windows x64, install with:

```powershell
winget install Notion.ntn
```

## Authentication

For an interactive workspace login:

```bash
ntn login
```

For remote machines without a browser, use `ntn login --no-browser` and then `ntn login poll`.

For unattended scripts and CI, use a Notion personal access token:

```bash
export NOTION_API_TOKEN="<your-personal-access-token>"
ntn api v1/users/me
```

The included skill documents workspace selection, API requests, file uploads, and safe diagnostics.

## Included Skill

- `notion`: Notion setup, authentication, API requests, and file uploads via `ntn`.
