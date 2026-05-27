# Browser Session Management

Run multiple isolated browser sessions concurrently with state persistence.

## Default pattern: one `default` session, `--persistent` every call

For day-to-day automation, **don't name sessions**. Skip `-s=`. Every call goes to the same `default` session — a real Chromium profile on disk. Add `--persistent` on every `open` so the profile survives.

```bash
# First time only (per site) — log in by hand
playwright-cli --headed open https://github.com/login --persistent

# Every later call — no login, on any site previously visited in default
playwright-cli open https://github.com/issues --persistent
playwright-cli snapshot
playwright-cli close
```

The `default` profile accumulates logins across sites. Visit each new site once with `--headed`; afterwards it stays signed in.

To pin a different default name for the current shell: `export PLAYWRIGHT_CLI_SESSION=main` (see "Environment Variable" below for the scope caveat).

## Named sessions (only when you need isolation)

Use `-s=<name>` only when two profiles need to coexist — e.g. two accounts on the same site, or a parallel test that must not see your other logins:

```bash
# Default session (no -s) holds your main work logins
playwright-cli open https://github.com --persistent

# Separate "alt" session for a second account on the same site
playwright-cli -s=alt open https://github.com --persistent
playwright-cli -s=alt fill e1 "alt-user@example.com"
```

## Browser Session Isolation Properties

Each browser session has independent:
- Cookies
- LocalStorage / SessionStorage
- IndexedDB
- Cache
- Browsing history
- Open tabs

## Browser Session Commands

```bash
# List all browser sessions
playwright-cli list

# Stop a browser session (close the browser)
playwright-cli close                # stop the default browser
playwright-cli -s=mysession close   # stop a named browser

# Stop all browser sessions
playwright-cli close-all

# Forcefully kill all daemon processes (for stale/zombie processes)
playwright-cli kill-all

# Delete browser session user data (profile directory)
playwright-cli delete-data                # delete default browser data
playwright-cli -s=mysession delete-data   # delete named browser data
```

## Environment Variable

Set a default browser session name via environment variable. **Scope: current shell only.** If your agent runs each command in a fresh shell, the variable won't carry over and later `close`/`list` calls will hit `default` instead — in that case, pass `-s=<name>` on every call.

```bash
# Interactive shell — works for the rest of this session
export PLAYWRIGHT_CLI_SESSION="mysession"
playwright-cli open https://example.com --persistent  # uses "mysession"
playwright-cli close                                   # closes "mysession"

# Agent / per-command shells — inline -s= is safer
playwright-cli -s=mysession open https://example.com --persistent
playwright-cli -s=mysession snapshot
playwright-cli -s=mysession close
```

## Common Patterns

### Concurrent Scraping

```bash
#!/bin/bash
# Scrape multiple sites concurrently — in-memory profiles (no --persistent) since each run is one-shot.
# Add --persistent if you'll re-run against the same sites later.

# Start all browsers
playwright-cli -s=site1 open https://site1.com &
playwright-cli -s=site2 open https://site2.com &
playwright-cli -s=site3 open https://site3.com &
wait

# Take snapshots from each
playwright-cli -s=site1 snapshot
playwright-cli -s=site2 snapshot
playwright-cli -s=site3 snapshot

# Cleanup
playwright-cli close-all
```

### A/B Testing Sessions

```bash
# Test different user experiences
playwright-cli -s=variant-a open "https://app.com?variant=a"
playwright-cli -s=variant-b open "https://app.com?variant=b"

# Compare
playwright-cli -s=variant-a screenshot
playwright-cli -s=variant-b screenshot
```

### Persistent Profile

By default, browser profile is kept in memory only. Use `--persistent` flag on `open` to persist the browser profile to disk:

```bash
# Use persistent profile — stored at ~/Library/Caches/ms-playwright/daemon/<workspace>/ud-<session>-chrome (macOS)
playwright-cli open https://example.com --persistent

# Use persistent profile with custom directory (e.g. ephemeral path in CI)
playwright-cli open https://example.com --profile=/path/to/profile
```

## Attaching to a Running Browser

Use `attach` to connect to a browser that is already running, instead of launching a new one.

**`attach` is not for reusing your everyday Chrome's logins.** Verified: `attach --cdp=chrome` opens a fresh in-memory context layered on top of the Chrome process — none of your personal cookies, tabs, or sessions are visible inside it. For login reuse use `open --persistent` ([see top of this file](#default-pattern-one-default-session---persistent-every-call)).

### Attach by channel name

Connect to a running Chrome or Edge instance by its channel name. The browser must have remote debugging enabled — navigate to `chrome://inspect/#remote-debugging` in the target browser and check "Allow remote debugging for this browser instance".

```bash
# Attach to Chrome (NB: empty in-memory context, not your logged-in profile)
playwright-cli attach --cdp=chrome
playwright-cli attach --cdp=chrome-canary
playwright-cli attach --cdp=msedge
playwright-cli attach --cdp=msedge-dev
```

Supported channels: `chrome`, `chrome-beta`, `chrome-dev`, `chrome-canary`, `msedge`, `msedge-beta`, `msedge-dev`, `msedge-canary`.

### Attach via CDP endpoint

Connect to a browser that exposes a Chrome DevTools Protocol endpoint (e.g. a remote browser in CI):

```bash
playwright-cli attach --cdp=http://localhost:9222
```

### Attach via browser extension

Real reuse of your everyday Chrome's logins, at the cost of manual setup and per-attach friction:

```bash
playwright-cli attach --extension=chrome
```

Prerequisites:
- Install the [Playwright Extension](https://chromewebstore.google.com/detail/playwright-extension/mmlmfjhmonkocbjadbfplnigmagldckm) in Chrome.
- Each attach prompts you in the extension UI to pick which tab to share. Setting `PLAYWRIGHT_MCP_EXTENSION_TOKEN=<token from extension>` auto-approves the connection dialog, but you still pick a tab.

For unattended automation, prefer `open --persistent`; for one-off reuse of your real browser session, `--extension` works.

## Default Browser Session

When `-s` is omitted, commands use the default browser session. Always include `--persistent` on `open` so the profile survives across calls (omitting it silently drops into an in-memory context):

```bash
# These use the same default browser session
playwright-cli open https://example.com --persistent
playwright-cli snapshot
playwright-cli close  # Stops default browser; profile remains on disk
```

## Browser Session Configuration

Configure a browser session with specific settings when opening:

```bash
# Open with config file
playwright-cli open https://example.com --config=.playwright/my-cli.json

# Open with specific browser
playwright-cli open https://example.com --browser=firefox

# Open in headed mode
playwright-cli open https://example.com --headed

# Open with persistent profile
playwright-cli open https://example.com --persistent
```

## Best Practices

### 1. Prefer the `default` session

For everyday use, skip `-s=` and let everything land in `default`. Sites you've logged into accumulate there. Reach for a named session only when you actually need isolation (parallel runs, alt account). If you do name one, pick a clear word (`alt`, `qa`, `bot-account`) — not `s1`.

### 2. Always Clean Up

```bash
# Stop browsers when done
playwright-cli -s=auth close
playwright-cli -s=scrape close

# Or stop all at once
playwright-cli close-all

# If browsers become unresponsive or zombie processes remain
playwright-cli kill-all
```

### 3. Delete Stale Browser Data

```bash
# Remove old browser data to free disk space
playwright-cli -s=oldsession delete-data
```
