# browse 스킬: Chrome 쿠키 재활용 설계

날짜: 2026-06-01

## 목표

사용자가 평소 쓰는 Chrome에 이미 로그인된 세션을 playwright-cli 세션으로 가져와
재활용한다. 매번 `--headed`로 손 로그인하는 대신, Chrome의 암호화된 쿠키를
복호화해 playwright 세션에 주입한다.

`~/dev/search`의 claude plugins(`ks-internal/import-cookies.sh`,
`ks-grafana/extract-cookies.sh`)에 검증된 구현이 있으므로, 그 방식을 그대로
포팅한다.

> 참고: bstack CLAUDE.md는 skill 스크립트에 TypeScript+bun을 규정하나, 사용자가
> bash를 명시적으로 요청했으므로 bash로 작성한다 (사용자 지시 우선).

## 아키텍처

```
extract-chrome-cookies.sh  ─(JSON)→  import-cookies.sh  ─(cookie-set)→  playwright-cli 세션
   │                                      │
   │ Keychain "Chrome Safe Storage" 키     │ 각 쿠키를 playwright-cli cookie-set 으로 주입
   │ → PBKDF2(sha1, saltysalt, 1003, 16)   │ 완료 후 reload
   │ → AES-128-CBC 복호화 (Cookies sqlite) │
   └── 도메인 쿠키 보유 프로필 자동 탐지
```

macOS 한정. Chrome v10/v11 쿠키 암호화 스킴을 따른다. bash가 메인이고, AES 복호화
부분만 python3 힙도큐먼트로 처리한다 (grafana 스크립트와 동일 방식, python3는 macOS
기본 포함). 의존성: `security`, `sqlite3`, `python3` (모두 macOS 내장).

## 컴포넌트

### 1. `scripts/extract-chrome-cookies.sh`

- 입력: `<domain>` 위치 인자 (임의 도메인), 선택적 `--chrome-profile <name>` 오버라이드
- macOS Keychain에서 `security find-generic-password -ws "Chrome Safe Storage"` 로
  Safe Storage 키 추출 → python3로 `pbkdf2_hmac("sha1", key, "saltysalt", 1003, 16)`
  → AES-128 키 hex
- 프로필 탐지 (요청 도메인 쿠키 보유 기준, kakaostyle 비특화):
  1. `--chrome-profile` 플래그가 있으면 그대로 사용
  2. 프로필이 하나뿐이면 그것 사용
  3. `Default` / `Profile *` 를 스캔해 해당 도메인 쿠키 개수 > 0 인 첫 프로필 선택
     (`sqlite3 <Cookies> "SELECT count(*) ... WHERE host_key LIKE '%<domain>%'"`)
  4. 못 찾으면 프로필 목록을 stderr에 출력하고 에러 (exit 1)
- 선택한 프로필의 `Cookies` sqlite DB를 temp로 복사 (Chrome이 원본 락) 후 조회:
  `SELECT host_key, path, is_secure, expires_utc, name, encrypted_value, is_httponly
  FROM cookies WHERE host_key LIKE '%<domain>%' OR host_key = '<domain>'`
- 복호화: python3 힙도큐먼트. v10/v11 prefix 제거 → `AES-128-CBC`, IV는 16바이트
  공백(`0x20`*16), PKCS7 패딩 제거 후 앞 32바이트(Chrome SHA256 도메인 헤더) 스킵
- 출력: stdout에 JSON 배열
  `[{name, value, domain, path, secure, httpOnly, expires?}]`
  - `expires`: `expires_utc > 0`일 때 `expires_utc/1e6 - 11644473600` (unix epoch), 아니면 생략

### 2. `scripts/import-cookies.sh`

- 입력: `<domain>` 위치 인자, 선택적 `--session <name>` (기본값 `default`),
  `--chrome-profile <name>` (extract로 전달)
- 같은 디렉토리의 `extract-chrome-cookies.sh`를 실행해 JSON 수신
- 쿠키가 없으면 stderr에 안내 후 exit 1
- 각 쿠키를 `playwright-cli -s=<session> cookie-set <name> <value>
  --domain <domain> --path <path> [--secure] [--httpOnly] [--expires <n>]` 로 주입
- 주입 후 `playwright-cli -s=<session> reload`
- stderr에 `N/M cookies injected` 요약

기본 세션을 `default`로 둔다 (참조 구현은 `ks` 하드코딩이었으나, browse 스킬의
기본 세션은 `default`이므로 일치시킨다).

## SKILL.md 변경

"Sessions & login" 섹션 아래에 **"Reusing your Chrome session (cookie import)"**
서브섹션 추가:

- 사용법: `${CLAUDE_PLUGIN_ROOT}/skills/browse/scripts/import-cookies.sh <domain>`
- macOS 한정, Keychain 접근 동의 프롬프트가 한 번 뜰 수 있음을 명시
- 손 로그인(`--headed --persistent`) 패턴의 대안임을 명시

기존 보안 경계(`eval`로 쿠키 읽지 말라)는 **유지**하되, 한 줄 예외 추가:

> 사용자가 명시적으로 요청한 세션 재활용은 전용 스크립트(`import-cookies.sh`)로만
> 수행하며, `eval`로 쿠키를 읽는 것과는 구별된다.

"Common rationalizations" 표의 `attach --cdp=chrome` 항목에 쿠키 import가 대안임을
한 줄 덧붙인다.

## 검증 기준

1. `extract-chrome-cookies.sh <domain>` → 유효한 JSON 배열 출력.
   verify: 실제 로그인된 도메인으로 실행해 쿠키 개수 > 0, 값이 평문으로 복호화됨
2. `import-cookies.sh <domain>` → playwright 세션 주입 후 해당 사이트 `open` 시
   로그인 상태. verify: `playwright-cli cookie-list`로 주입 확인 + snapshot으로 로그인 확인
3. 의존성은 macOS 내장 도구만 (`security`, `sqlite3`, `python3`) — 외부 설치 0개

## YAGNI로 제외

- grafana `extract-cookies.sh`의 로그인 polling/대기 로직 — 사용자가 이미 로그인했다고 가정
- 인증 검증(`curl /api/user`) — 도메인마다 엔드포인트가 다름
- 비-macOS 지원 — Keychain/Safe Storage가 OS별로 다름, 현 사용 환경은 macOS
