# browse 스킬: Chrome 쿠키 재활용 설계

날짜: 2026-06-01

## 목표

사용자가 평소 쓰는 Chrome에 이미 로그인된 세션을 playwright-cli 세션으로 가져와
재활용한다. 매번 `--headed`로 손 로그인하는 대신, Chrome의 암호화된 쿠키를
복호화해 playwright 세션에 주입한다.

`~/dev/search`의 claude plugins(`ks-internal/import-cookies.sh`)에 검증된 구현이
있으므로, 그 방식을 bstack 프로젝트 규칙(TypeScript + bun)에 맞게 포팅한다.

## 아키텍처

```
extract-chrome-cookies.ts  ─(JSON)→  import-cookies.ts  ─(cookie-set)→  playwright-cli 세션
   │                                      │
   │ Keychain "Chrome Safe Storage" 키     │ 각 쿠키를 playwright-cli cookie-set 으로 주입
   │ → PBKDF2(sha1, saltysalt, 1003, 16)   │ 완료 후 reload
   │ → AES-128-CBC 복호화 (Cookies sqlite) │
   └── kakaostyle 계정 프로필 자동 탐지
```

macOS 한정. Chrome v10/v11 쿠키 암호화 스킴을 따른다.

## 컴포넌트

### 1. `scripts/extract-chrome-cookies.ts`

- 입력: `<domain>` 위치 인자 (임의 도메인)
- macOS Keychain에서 `security find-generic-password -ws "Chrome Safe Storage"` 로
  Safe Storage 키 추출
- `node:crypto`의 `pbkdf2Sync(key, "saltysalt", 1003, 16, "sha1")` → AES-128 키
- `createDecipheriv("aes-128-cbc", key, iv)` 로 복호화. IV는 16바이트 공백(`0x20` * 16),
  복호화 결과에서 PKCS7 패딩 제거 후 앞 32바이트(Chrome SHA256 도메인 해시 헤더) 스킵
- Chrome `~/Library/Application Support/Google/Chrome/<profile>/Cookies` sqlite DB를
  temp 파일로 복사 후 `bun:sqlite`로 조회 (Chrome이 원본을 락하므로)
- 프로필 탐지: `Default` → `Profile 1..19` 순서로 `Preferences`의 `account_info[0].email`이
  `@kakaostyle.com` 인 프로필 선택, 없으면 `Default`
- 쿼리: `SELECT host_key, path, is_secure, expires_utc, name, encrypted_value, is_httponly
  FROM cookies WHERE host_key LIKE '%<domain>%' OR host_key = '<domain>'`
- 출력: stdout에 JSON 배열
  `[{name, value, domain, path, secure, httpOnly, expires?}]`
  - `expires`: `expires_utc > 0`일 때 `expires_utc/1e6 - 11644473600` (unix epoch), 아니면 생략

### 2. `scripts/import-cookies.ts`

- 입력: `<domain>` 위치 인자, 선택적 `--session <name>` (기본값 `default`)
- 같은 디렉토리의 `extract-chrome-cookies.ts`를 자식 프로세스로 실행해 JSON 수신
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

- 사용법: `bun ${CLAUDE_PLUGIN_ROOT}/skills/browse/scripts/import-cookies.ts <domain>`
- macOS 한정, Keychain 접근 동의 프롬프트가 한 번 뜰 수 있음을 명시
- 손 로그인(`--headed --persistent`) 패턴의 대안임을 명시

기존 보안 경계(`eval`로 쿠키 읽지 말라)는 **유지**하되, 한 줄 예외 추가:

> 사용자가 명시적으로 요청한 세션 재활용은 전용 스크립트(`import-cookies.ts`)로만
> 수행하며, `eval`로 쿠키를 읽는 것과는 구별된다.

"Common rationalizations" 표의 `attach --cdp=chrome` 항목에 쿠키 import가 대안임을
한 줄 덧붙인다.

## 검증 기준

1. `bun extract-chrome-cookies.ts <domain>` → 유효한 JSON 배열 출력.
   verify: 실제 로그인된 도메인으로 실행해 쿠키 개수 > 0, 값이 평문으로 복호화됨
2. `bun import-cookies.ts <domain>` → playwright 세션 주입 후 해당 사이트 `open` 시
   로그인 상태. verify: `playwright-cli cookie-list`로 주입 확인 + snapshot으로 로그인 확인
3. 외부 npm 의존성 0개 (node 내장 `crypto` + `bun:sqlite`만 사용)

## YAGNI로 제외

- grafana `extract-cookies.sh`의 로그인 polling/대기 로직 — 사용자가 이미 로그인했다고 가정
- 인증 검증(`curl /api/user`) — 도메인마다 엔드포인트가 다름
- `--chrome-profile` 수동 지정 플래그 — 자동 탐지로 충분, 필요 시 후속 추가
- 비-macOS 지원 — Keychain/Safe Storage가 OS별로 다름, 현 사용 환경은 macOS
