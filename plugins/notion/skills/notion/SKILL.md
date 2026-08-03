---
name: notion
description: Use the official ntn CLI for Notion workspace authentication, API requests, and file uploads.
---

# Notion

Route Notion workspace requests through the official `ntn` CLI. This plugin intentionally does not configure an MCP server.

## Setup

```bash
curl -fsSL https://ntn.dev | bash
ntn --version
ntn login
ntn login --no-browser
ntn login poll
ntn doctor
```

Use `ntn login` for browser-based authentication. On a remote machine or CI runner, use `ntn login --no-browser`, complete the displayed URL and verification code in a browser, then run `ntn login poll` on the original machine. Use a personal access token for unattended scripts.

## Authentication boundaries

```bash
NOTION_API_TOKEN=... ntn api v1/users/me
NOTION_WORKSPACE_ID="$WORKSPACE_ID" ntn api v1/users/me
```

`NOTION_API_TOKEN` takes precedence over the keychain session for that command. `NOTION_WORKSPACE_ID` targets a specific workspace without changing the default workspace. Treat the token and any file-based credential store as secrets.

## API patterns

```bash
ntn api v1/users
ntn api v1/search query=roadmap page_size:=10
ntn api v1/search query==roadmap page_size==10
ntn api "v1/pages/$PAGE_ID" -X PATCH archived:=true
```

Inline request assignments use these rules:

- `=` creates a string body field.
- `:=` preserves the value's JSON type, such as boolean, number, array, object, or `null`.
- `==` creates a query parameter.
- Only one body source may be used per request: stdin JSON, `--data`, or inline body fields. Headers and query parameters may still be combined with that body source.

Use `--verbose` to inspect request and response metadata. Authorization is redacted by default. Never use `--unsafe-verbose` in shared logs because it can expose the bearer token.

## Files

```bash
ntn files create --plain < ./photo.png
ntn files get "$FILE_UPLOAD_ID"
ntn files list
```

`ntn files create --plain` prints the upload ID first, which can be stored in `FILE_UPLOAD_ID`. Check the upload with `ntn files get` before attaching it to a Notion page through `ntn api`.
