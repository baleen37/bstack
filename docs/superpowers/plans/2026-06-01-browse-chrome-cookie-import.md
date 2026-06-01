# browse Chrome 쿠키 재활용 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** browse 스킬에 macOS Chrome의 로그인 쿠키를 복호화해 playwright-cli 세션으로 주입하는 스크립트 2개와 사용법 문서를 추가한다.

**Architecture:** `extract-chrome-cookies.sh`가 Keychain의 Chrome Safe Storage 키로 쿠키 sqlite DB를 복호화해 JSON으로 출력하고, `import-cookies.sh`가 그 JSON을 받아 `playwright-cli cookie-set`으로 세션에 주입한다. bash가 메인이며 AES 복호화만 python3 힙도큐먼트로 처리한다.

**Tech Stack:** bash, python3 (macOS 내장), sqlite3 (macOS 내장), `security` (Keychain), playwright-cli

---

## File Structure

- Create: `plugins/me/skills/browse/scripts/extract-chrome-cookies.sh` — Chrome 쿠키 추출/복호화 → JSON
- Create: `plugins/me/skills/browse/scripts/import-cookies.sh` — JSON → playwright-cli 세션 주입
- Modify: `plugins/me/skills/browse/SKILL.md` — 사용법 서브섹션 + 보안 경계 예외 한 줄

테스트 메모: 두 스크립트는 실제 Chrome Keychain/쿠키 DB에 의존하므로 BATS 자동 단위
테스트가 불가능하다. 대신 각 Task는 **수동 검증 단계**(실제 도메인으로 실행)로 통과를
확인한다. 검증 도메인은 사용자가 평소 Chrome에 로그인해 둔 사이트를 사용한다 (예시로
`github.com`을 쓰되, 실행 시점에 로그인된 도메인으로 대체).

---

## Task 1: extract-chrome-cookies.sh — 골격 + 프로필 탐지

**Files:**
- Create: `plugins/me/skills/browse/scripts/extract-chrome-cookies.sh`

- [ ] **Step 1: 디렉토리 생성 후 스크립트 작성 (프로필 탐지까지)**

```bash
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
```

- [ ] **Step 2: 실행 권한 부여 + 프로필 탐지 수동 검증**

Run:
```bash
chmod +x plugins/me/skills/browse/scripts/extract-chrome-cookies.sh
plugins/me/skills/browse/scripts/extract-chrome-cookies.sh --list-profiles
plugins/me/skills/browse/scripts/extract-chrome-cookies.sh github.com 2>&1 | grep "Using Chrome profile"
```
Expected: `--list-profiles`가 프로필 목록 출력. 두 번째 명령이 `Using Chrome profile: <name>`를 stderr로 출력하고, 그 뒤 `die`나 오류 없이 진행 (아직 출력 로직 없으므로 스크립트는 정상 종료). 로그인된 도메인이 github.com이 아니면 실제 로그인 도메인으로 대체.

- [ ] **Step 3: Commit**

```bash
git add plugins/me/skills/browse/scripts/extract-chrome-cookies.sh
git commit -m "feat(browse): add chrome cookie extractor skeleton with profile detection"
```

---

## Task 2: extract-chrome-cookies.sh — 복호화 + JSON 출력

**Files:**
- Modify: `plugins/me/skills/browse/scripts/extract-chrome-cookies.sh` (Step 1 끝부분에 이어서 append)

- [ ] **Step 1: Keychain 키 추출 + DB 복사 + python3 복호화 블록 추가**

`COOKIES_DB` 확인 줄(`[ -f "$COOKIES_DB" ] || die ...`) 바로 아래에 이어서 추가:

```bash
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
```

- [ ] **Step 2: 수동 검증 — JSON 출력 + 평문 복호화**

Run:
```bash
plugins/me/skills/browse/scripts/extract-chrome-cookies.sh github.com 2>/dev/null | python3 -m json.tool | head -20
plugins/me/skills/browse/scripts/extract-chrome-cookies.sh github.com 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print('count:', len(d)); print('sample value len:', len(d[0]['value']) if d else 0)"
```
Expected: 유효한 JSON 배열. `count > 0`. `value`가 빈 문자열이 아니고 깨진 바이트 없이 평문 (예: 세션 토큰 문자열). 로그인 도메인이 github.com이 아니면 대체.

- [ ] **Step 3: Commit**

```bash
git add plugins/me/skills/browse/scripts/extract-chrome-cookies.sh
git commit -m "feat(browse): decrypt chrome cookies and emit JSON"
```

---

## Task 3: import-cookies.sh — playwright 세션 주입

**Files:**
- Create: `plugins/me/skills/browse/scripts/import-cookies.sh`

- [ ] **Step 1: 스크립트 작성**

```bash
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

SESSION="$SESSION" DOMAIN="$DOMAIN" python3 - << 'PYEOF'
import json, os, subprocess, sys

cookies = json.load(sys.stdin)
session = os.environ['SESSION']
injected = 0
for c in cookies:
    cmd = ['playwright-cli', f'-s={session}', 'cookie-set', c['name'], c['value'],
           '--domain', c['domain'], '--path', c['path']]
    if c.get('secure'):   cmd.append('--secure')
    if c.get('httpOnly'): cmd.append('--httpOnly')
    if 'expires' in c:    cmd += ['--expires', str(c['expires'])]
    r = subprocess.run(cmd, capture_output=True, timeout=15)
    if r.returncode == 0:
        injected += 1
print(f"{injected}/{len(cookies)} cookies injected into session '{session}'", file=sys.stderr)
PYEOF
<<< "$COOKIES_JSON" 2>&1 || true

playwright-cli -s="$SESSION" reload >/dev/null 2>&1 || true
```

> 주의: 위 python3 힙도큐먼트는 stdin을 `<<<` here-string으로 받는다. bash에서
> here-doc(`<< 'PYEOF'`)과 here-string(`<<<`)을 동시에 쓸 수 없으므로, Step 1.5에서
> 이를 파이프 방식으로 교정한다.

- [ ] **Step 1.5: stdin 전달을 파이프로 교정**

위 블록의 `SESSION=... python3 - << 'PYEOF' ... PYEOF` + `<<< "$COOKIES_JSON"` 부분을
아래로 교체 (here-doc과 here-string 충돌 제거 — JSON을 echo로 파이프):

```bash
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
```

최종 스크립트는 Step 1의 헤더/인자 파싱 + `COOKIES_JSON` 추출 + 이 교정된 주입 블록으로 구성된다 (Step 1의 here-doc 주입 블록은 남기지 않는다).

- [ ] **Step 2: 실행 권한 + 수동 검증 (주입 → cookie-list 확인)**

Run:
```bash
chmod +x plugins/me/skills/browse/scripts/import-cookies.sh
playwright-cli open https://github.com --persistent >/dev/null 2>&1
plugins/me/skills/browse/scripts/import-cookies.sh github.com
playwright-cli --raw cookie-list --domain=github.com | python3 -c "import json,sys; print('cookies in session:', len(json.load(sys.stdin)))"
```
Expected: `N/M cookies injected into session "default"` (N>0) stderr 출력. `cookie-list`가 0보다 큰 개수 반환. 로그인 도메인이 github.com이 아니면 대체.

- [ ] **Step 3: 수동 검증 — 로그인 상태 확인**

Run:
```bash
playwright-cli goto https://github.com
playwright-cli snapshot --depth=6 | grep -i -E "sign out|your profile|avatar|@" | head -3
```
Expected: 로그인된 상태를 나타내는 요소(프로필/아바타/Sign out 등)가 snapshot에 보임. 로그인 안 된 상태면 쿠키 주입이 실패한 것 → extract 출력과 cookie-set 옵션을 재점검.

- [ ] **Step 4: Commit**

```bash
git add plugins/me/skills/browse/scripts/import-cookies.sh
git commit -m "feat(browse): inject chrome cookies into playwright session"
```

---

## Task 4: SKILL.md 문서화

**Files:**
- Modify: `plugins/me/skills/browse/SKILL.md`

- [ ] **Step 1: "Sessions & login" 섹션 끝에 서브섹션 추가**

`SKILL.md`에서 "Sessions & login" 섹션의 마지막 단락(profile location을 설명하는 줄, `~/Library/Caches/ms-playwright/...`로 시작) 바로 뒤에 아래 블록을 삽입:

```markdown
### Reusing your Chrome session (cookie import, macOS)

Instead of logging in by hand, import cookies from your everyday Chrome for a given domain into a playwright-cli session. Decrypts Chrome's cookie DB via the macOS Keychain and injects each cookie with `cookie-set`.

```bash
# Open the session first (persistent), then import
playwright-cli open https://example.com --persistent
${CLAUDE_PLUGIN_ROOT}/skills/browse/scripts/import-cookies.sh example.com
playwright-cli goto https://example.com    # now logged in
```

- macOS only. The first run may show a Keychain access prompt ("playwright-cli wants to use the 'Chrome Safe Storage' key") — approve it.
- The profile holding cookies for the domain is auto-detected; override with `--chrome-profile "Profile 2"`.
- Target a named session with `--session <name>` (default `default`).
- This is an alternative to the hand-login (`--headed --persistent`) flow above. Works only if you're already logged in to the domain in Chrome.
```

- [ ] **Step 2: 보안 경계 예외 한 줄 추가**

`SKILL.md`의 `eval` / `run-code` constraints 블록에서 "No credential access" 항목 끝(`(Use the dedicated cookie-* / localstorage-* commands ...)` 괄호 뒤)에 다음 문장을 추가:

```markdown
Reusing your real Chrome login is allowed only via the dedicated `import-cookies.sh` script when the user explicitly asks — this is distinct from reading cookies through `eval`, which remains forbidden.
```

- [ ] **Step 3: rationalizations 표 항목 보강**

`Common rationalizations` 표에서 `attach --cdp=chrome` 행의 Reality 칸 끝에 다음을 덧붙임:

```markdown
 To reuse your real Chrome login, import its cookies with `scripts/import-cookies.sh <domain>`.
```

- [ ] **Step 4: 수동 검증 — 문서 정합성**

Run:
```bash
grep -n "import-cookies.sh" plugins/me/skills/browse/SKILL.md
```
Expected: 3개 이상의 매치 (서브섹션, 보안 예외, rationalizations 표). 깨진 마크다운 없이 읽힘.

- [ ] **Step 5: Commit**

```bash
git add plugins/me/skills/browse/SKILL.md
git commit -m "docs(browse): document chrome cookie import and security exception"
```

---

## Self-Review 결과

**Spec 커버리지:**
- extract-chrome-cookies.sh (Keychain, PBKDF2, AES-128-CBC, sqlite, 도메인 프로필 탐지, JSON) → Task 1+2 ✓
- import-cookies.sh (cookie-set 주입, reload, --session 기본 default) → Task 3 ✓
- SKILL.md (서브섹션, 보안 예외, rationalizations) → Task 4 ✓
- 의존성 macOS 내장만 → 코드가 security/sqlite3/python3만 사용 ✓
- YAGNI 제외 항목(로그인 polling, 인증 검증, 비-macOS) → 계획에 미포함 ✓

**Placeholder 스캔:** TBD/TODO 없음. 모든 코드 블록 완전.

**타입 정합성:** extract의 JSON 키(`name,value,domain,path,secure,httpOnly,expires`)를 import가 동일하게 소비. `--session`/`--chrome-profile` 플래그명 일관. ✓

**알려진 위험:** Task 3의 here-doc/here-string 충돌을 Step 1.5에서 명시적으로 교정. 수동 검증 도메인은 실행 시점 로그인 상태에 의존 — github.com 예시는 대체 가능.
