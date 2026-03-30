# Daily Standup Template

Use this template exactly when generating the standup report. Maintain spacing and structure.

## Template

```
어제 한 업무는 무엇인가요?
어제 한 업무
  - {ISSUE_KEY} {ISSUE_SUMMARY}
  - {ISSUE_KEY} {ISSUE_SUMMARY}




오늘 할 일을 적어보아요
- {ISSUE_KEY} {ISSUE_SUMMARY}
  - {ISSUE_KEY} {ISSUE_SUMMARY}
```

## Placeholder Rules

| Placeholder | Description |
|-------------|-------------|
| `{ISSUE_KEY}` | Jira issue key (e.g. `SEARCH-12134`) |
| `{ISSUE_SUMMARY}` | Issue title as-is from Jira |

## Formatting Rules

- 어제 한 업무: 들여쓰기 두 칸 (`  - `)
- 오늘 할 일: 첫 번째 레벨 (`- `), 하위 항목은 들여쓰기 두 칸 (`  - `)
- 섹션 사이 빈 줄 3개 유지
- 이슈 키와 제목만 포함. 링크, 상태, 날짜 표시 불필요

## Example Output

```
어제 한 업무는 무엇인가요?
어제 한 업무
  - SEARCH-12134 user 사용자 정보 signal 생성
  - SEARCH-12658 Bronze 파이프라인 Raw JSON String 저장 구조로 전환 (5개 토픽)
  - SEARCH-12562 signal 배치 주기 단축 (daily → 1시간)




오늘 할 일을 적어보아요
- SEARCH-12625 product-traits.v3 → v4 전환에 따른 검색 쿼리 작업 (기본 query 작업)
  - SEARCH-12563 Slow path signal 증분 처리 구조 전환
```
