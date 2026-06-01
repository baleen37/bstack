#!/usr/bin/env bash
# Chrome 프로필에서 특정 도메인의 쿠키를 복호화하여 JSON으로 출력 (macOS 전용).
#
# Usage:
#   extract-chrome-cookies.sh <domain> [--chrome-profile <name>]
#   extract-chrome-cookies.sh --list-profiles
#
# stdout: [{name, value, domain, path, secure, httpOnly, expires?}, ...]
# 의존성: security, sqlite3, python3 (모두 macOS 내장)
set -euo pipefail

die() { echo "Error: $*" >&2; exit 1; }

CHROME_DIR="$HOME/Library/Application Support/Google/Chrome"

# --- --list-profiles ---
if [ "${1:-}" = "--list-profiles" ]; then
  for dir in "$CHROME_DIR"/Default "$CHROME_DIR"/Profile\ *; do
    [ -d "$dir" ] || continue
    echo "$(basename "$dir")"
  done
  exit 0
fi

DOMAIN="${1:?Usage: extract-chrome-cookies.sh <domain> [--chrome-profile <name>]}"
shift

CHROME_PROFILE_OVERRIDE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --chrome-profile) CHROME_PROFILE_OVERRIDE="${2:?--chrome-profile needs a value}"; shift 2 ;;
    *) die "Unknown option: $1" ;;
  esac
done

[ -d "$CHROME_DIR" ] || die "Chrome dir not found: $CHROME_DIR (macOS Chrome only)"

# --- 프로필 선택: override > 단일 프로필 > 도메인 쿠키 보유 프로필 ---
_count_cookies() {
  local db="$CHROME_DIR/$1/Cookies"
  [ -f "$db" ] || { echo 0; return; }
  sqlite3 "$db" "SELECT count(*) FROM cookies WHERE host_key LIKE '%${DOMAIN}%'" 2>/dev/null || echo 0
}

CHROME_PROFILE=""
if [ -n "$CHROME_PROFILE_OVERRIDE" ]; then
  CHROME_PROFILE="$CHROME_PROFILE_OVERRIDE"
else
  ALL_PROFILES=()
  for dir in "$CHROME_DIR"/Default "$CHROME_DIR"/Profile\ *; do
    [ -d "$dir" ] || continue
    ALL_PROFILES+=("$(basename "$dir")")
  done
  [ ${#ALL_PROFILES[@]} -gt 0 ] || die "No Chrome profiles found in $CHROME_DIR"

  if [ ${#ALL_PROFILES[@]} -eq 1 ]; then
    CHROME_PROFILE="${ALL_PROFILES[0]}"
  else
    for p in "${ALL_PROFILES[@]}"; do
      if [ "$(_count_cookies "$p")" -gt 0 ]; then CHROME_PROFILE="$p"; break; fi
    done
  fi

  if [ -z "$CHROME_PROFILE" ]; then
    echo "No profile has cookies for '$DOMAIN'. Available profiles:" >&2
    printf '  %s\n' "${ALL_PROFILES[@]}" >&2
    echo "Re-run with --chrome-profile <name>." >&2
    exit 1
  fi
fi

echo "Using Chrome profile: $CHROME_PROFILE" >&2

COOKIES_DB="$CHROME_DIR/$CHROME_PROFILE/Cookies"
[ -f "$COOKIES_DB" ] || die "Cookie DB not found: $COOKIES_DB"
