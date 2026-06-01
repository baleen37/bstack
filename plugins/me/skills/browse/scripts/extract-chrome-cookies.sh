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

# --- Keychain에서 Chrome Safe Storage 키 → AES-128 키 hex ---
CHROME_KEY=$(security find-generic-password -ws "Chrome Safe Storage" 2>/dev/null) \
  || die "Could not read 'Chrome Safe Storage' from Keychain. Open Chrome at least once."

DERIVED_KEY=$(python3 -c "
import hashlib
key = hashlib.pbkdf2_hmac('sha1', '$CHROME_KEY'.encode(), b'saltysalt', 1003, dklen=16)
print(key.hex())
")

# --- Chrome이 DB를 락하므로 temp로 복사 ---
TEMP_DB=$(mktemp "${TMPDIR:-/tmp}/chrome_cookies.XXXXXX")
trap 'rm -f "${TEMP_DB:-}"' EXIT
cp "$COOKIES_DB" "$TEMP_DB"

# --- 조회 + 복호화 + JSON 출력 ---
CHROME_DERIVED_KEY="$DERIVED_KEY" python3 - "$TEMP_DB" "$DOMAIN" << 'PYEOF'
import json, os, sqlite3, sys

def decrypt(enc, key_hex):
    if not enc:
        return ""
    if enc[:3] not in (b'v10', b'v11'):
        return enc.decode('utf-8', errors='replace')
    data = enc[3:]
    key = bytes.fromhex(key_hex)
    iv = b' ' * 16
    try:
        from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
        from cryptography.hazmat.backends import default_backend
        dec = Cipher(algorithms.AES(key), modes.CBC(iv), backend=default_backend()).decryptor()
        out = dec.update(data) + dec.finalize()
    except ImportError:
        import subprocess
        proc = subprocess.run(
            ['openssl', 'enc', '-aes-128-cbc', '-d', '-K', key_hex, '-iv', '20'*16, '-nopad'],
            input=data, capture_output=True)
        if proc.returncode != 0:
            return ""
        out = proc.stdout
    pad = out[-1]
    if 0 < pad <= 16:
        out = out[:-pad]
    return out[32:].decode('utf-8', errors='replace')  # skip 32-byte Chrome header

db, domain = sys.argv[1], sys.argv[2]
key_hex = os.environ['CHROME_DERIVED_KEY']

conn = sqlite3.connect(db)
rows = conn.execute(
    "SELECT host_key, path, is_secure, expires_utc, name, encrypted_value, is_httponly "
    "FROM cookies WHERE host_key LIKE ? OR host_key = ?",
    (f'%{domain}%', domain)).fetchall()
conn.close()

cookies = []
for host_key, path, is_secure, expires_utc, name, enc, is_httponly in rows:
    value = decrypt(enc, key_hex)
    if not value:
        continue
    c = {"name": name, "value": value, "domain": host_key, "path": path,
         "secure": bool(is_secure), "httpOnly": bool(is_httponly)}
    if expires_utc > 0:
        c["expires"] = int(expires_utc / 1_000_000 - 11644473600)
    cookies.append(c)

print(json.dumps(cookies))
PYEOF
