# Auto-Updater Config Design

**Date:** 2026-02-01
**Author:** Jiho + Bot
**Status:** Approved

## Overview

auto-updater에 config 개념을 도입하여 여러 마켓플레이스와 특정 플러그인 업데이트를 지원한다.

## Config Structure

**File:** `plugins/auto-updater/config.json`

```json
{
  "marketplaces": [
    {
      "name": "baleen-plugins"
    },
    {
      "name": "upstream-marketplace",
      "plugins": ["episodic-memory"]
    }
  ]
}
```

**Rules:**
- `plugins` 필드가 없으면 해당 마켓플레이스의 모든 플러그인 업데이트
- `plugins` 필드가 있으면 명시된 플러그인만 업데이트
- config 파일이 없으면 기본값: `[{"name": "baleen-plugins"}]`

## Architecture

```
plugins/auto-updater/
├── config.json           # 설정 파일
├── scripts/
│   ├── lib/
│   │   ├── config.sh     # config 로드/파싱 함수
│   │   └── version-compare.sh  # 버전 비교 함수 (기존 유지)
│   ├── update.sh         # 메인 업데이트 스크립트
│   └── check.sh          # 체크만 하는 스크립트
└── .claude-plugin/
    └── plugin.json
```

## Data Flow

1. `load_config()` - config 로드 또는 기본값 사용
2. 각 마켓플레이스 순회:
   - marketplace.json 다운로드
   - `get_plugins_for_marketplace()`로 플러그인 필터링
   - 설치된 플러그인 확인 (`claude plugin list --json`)
   - 버전 비교 및 업데이트
3. 결과 출력

## Error Handling

| Scenario | Action |
|----------|--------|
| config.json 파싱 실패 | 기본값 사용, 경고 메시지 |
| marketplace.json 다운로드 실패 | 해당 마켓플레이스 건너뜀 |
| 잘못된 마켓플레이스 이름 | 경고 후 건너뜀 |
| 플러그인 업데이트 실패 | 실패 메시지, 다른 플러그인 계속 |

**Exit codes:**
- 0: 성공 (일부 실패 있어도 계속)
- 1: 치명적 오류

## Implementation Files

**New:**
- `config.json`
- `scripts/lib/config.sh`
- `scripts/update.sh`
- `scripts/check.sh`

**Delete:**
- `update-all-plugins.sh`
- `update-checker.sh`
- `check-and-update.sh`

**Modify:**
- `/update-all-plugins` skill → `update.sh` 호출
