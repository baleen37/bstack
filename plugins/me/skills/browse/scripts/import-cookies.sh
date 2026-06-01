#!/usr/bin/env bash
# Chrome 프로필 쿠키를 복호화하여 playwright-cli 세션에 주입 (macOS 전용).
#
# Usage:
#   import-cookies.sh <domain> [--session <name>] [--chrome-profile <name>]
#
# 기본 세션은 'default' (browse 스킬 기본 세션과 일치).
set -euo pipefail

die() { echo "Error: $*" >&2; exit 1; }

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

DOMAIN="${1:?Usage: import-cookies.sh <domain> [--session <name>] [--chrome-profile <name>]}"
shift

SESSION="default"
EXTRACT_ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --session) SESSION="${2:?--session needs a value}"; shift 2 ;;
    --chrome-profile) EXTRACT_ARGS+=(--chrome-profile "${2:?--chrome-profile needs a value}"); shift 2 ;;
    *) die "Unknown option: $1" ;;
  esac
done

COOKIES_JSON=$("$SCRIPT_DIR/extract-chrome-cookies.sh" "$DOMAIN" "${EXTRACT_ARGS[@]}")
[ -n "$COOKIES_JSON" ] && [ "$COOKIES_JSON" != "[]" ] \
  || die "No cookies found for '$DOMAIN' in Chrome."

echo "$COOKIES_JSON" | SESSION="$SESSION" python3 -c '
import json, os, subprocess, sys
cookies = json.load(sys.stdin)
session = os.environ["SESSION"]
injected = 0
for c in cookies:
    cmd = ["playwright-cli", f"-s={session}", "cookie-set", c["name"], c["value"],
           "--domain", c["domain"], "--path", c["path"]]
    if c.get("secure"):   cmd.append("--secure")
    if c.get("httpOnly"): cmd.append("--httpOnly")
    if "expires" in c:    cmd += ["--expires", str(c["expires"])]
    r = subprocess.run(cmd, capture_output=True, timeout=15)
    if r.returncode == 0:
        injected += 1
print(f"{injected}/{len(cookies)} cookies injected into session \"{session}\"", file=sys.stderr)
'

playwright-cli -s="$SESSION" reload >/dev/null 2>&1 || true
