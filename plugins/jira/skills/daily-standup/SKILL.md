---
name: daily-standup
description: >
  Generate a daily standup report by fetching the current user's Jira issues.
  When Claude needs to: (1) Write a daily standup, (2) Summarize yesterday's work and today's plan,
  (3) Generate a 데일리 스크럼 or 일일 업무 보고, or (4) Prepare a daily status update.
  Queries Jira for recently updated issues and in-progress work, then formats output using the
  standard standup template.
---

# Daily Standup

## Keywords

daily standup, 데일리, 어제 한 일, 오늘 할 일, 일일 업무, 스크럼, daily scrum, standup report,
업무 보고, 진행 상황, 오늘 업무, 어제 업무

Fetch the current user's Jira issues and format them into a daily standup report.

---

## Workflow

### Step 1: Determine Previous Workday

Calculate the lookback period based on today's day of week:

- **Monday** → `-3d` (Friday)
- **Tuesday–Friday** → `-1d`
- **Saturday/Sunday** → `-1d`

Use `currentDate` from context to determine day of week.

### Step 2: Fetch Jira Issues

Run three queries **in parallel**. Use `{LOOKBACK}` from Step 1.

모든 쿼리 공통 설정:
- `AND issuetype NOT IN (Epic, Initiative)`
- `fields: ["summary", "status", "key", "-description"]` — `-description`으로 description 제외 필수
- `responseContentFormat: "markdown"`

**Query A — 오늘 할 일** (현재 In Progress):

```jql
assignee = currentUser() AND issuetype NOT IN (Epic, Initiative) AND status = "In Progress" ORDER BY updated DESC
```

`maxResults: 5`

**Query B — 어제 한 일 후보** (최근 완료된 이슈):

```jql
assignee = currentUser() AND issuetype NOT IN (Epic, Initiative) AND status = "Done" AND updated >= -{LOOKBACK} ORDER BY updated DESC
```

`maxResults: 15`

**Query C — 참고용 Backlog** (upcoming work):

```jql
assignee = currentUser() AND issuetype NOT IN (Epic, Initiative) AND status = "Backlog" ORDER BY updated DESC
```

`maxResults: 5`

> **설계 근거:** In Progress와 Done을 별도 쿼리로 분리하면 (1) maxResults 제한으로 Done 이슈가 잘리는 문제 방지, (2) status 정렬 순서에 의존하지 않음, (3) 각 쿼리의 결과를 명확히 분류 가능.

---

### Step 3: Ask User to Confirm

Query 결과를 한 번에 보여주고 **한 번의 응답**으로 처리합니다.

다음 형식으로 출력하고 사용자 응답을 기다립니다:

```
📋 어제 한 업무 후보 ({이전 업무일} 기준):
1. {ISSUE_KEY} {ISSUE_SUMMARY}
2. {ISSUE_KEY} {ISSUE_SUMMARY}
...

📌 참고용 Backlog:
a. {ISSUE_KEY} {ISSUE_SUMMARY}
b. {ISSUE_KEY} {ISSUE_SUMMARY}
...

어제 실제로 작업한 항목 번호를 골라주세요. (예: 1,3,5 / 전체 / 엔터=없음)
오늘 할 일에 추가할 Backlog 항목은? (예: a,b / 엔터=없음)
```

- Done 이슈가 없으면 "어제 한 업무 후보" 섹션 생략
- Backlog 이슈가 없으면 "참고용 Backlog" 섹션 생략
- 둘 다 없으면 질문 없이 Step 4로 진행

> **AskUserQuestion을 사용하지 않는 이유:** 옵션 수 제한(2~4개)이 있어 Done 이슈가 많을 때 대응 불가. 텍스트 기반 번호 선택이 더 유연합니다.

---

### Step 4: Output the Standup Report

Format and print the final report using the template in `references/standup-template.md`.

- **어제 한 일**: 사용자가 선택한 Done 이슈 (Query B에서 선택)
- **오늘 할 일**:
  - 첫 번째 레벨 (`- `): Query A의 In Progress 이슈 (자동 포함)
  - 하위 레벨 (`  - `): 사용자가 추가한 Backlog 항목 (Query C에서 선택)

---

### Step 5: (macOS만) Slack용 클립보드 복사 제안

**플랫폼 체크:** `uname -s` 가 `Darwin` 이 아니면 Step 5 전체를 건너뛰고 워크플로우를 종료합니다. 사용자에게 언급할 필요도 없음 (macOS pasteboard 전용 기능이라 다른 OS에서는 의미 없음).

리포트를 출력한 뒤 사용자에게 한 줄로 물어봅니다:

```
Slack에 붙여넣기 좋게 클립보드로 복사할까요? (이슈 키가 하이퍼링크로 변환됩니다) [y/N]
```

**승인으로 간주하는 응답:** `y`, `yes`, `ㅇ`, `예`, `네`, `응` (대소문자 무시).
그 외는 거부로 간주하고 아무 동작도 하지 않고 종료.

**승인 시 실행:** Step 4에서 출력한 리포트 본문(섹션 빈 줄 포함 전체)을 heredoc으로 스크립트에 stdin 전달. **heredoc 본문은 플레이스홀더 문구가 아니라 Step 4에서 실제로 출력했던 리포트 그대로** 붙여넣어야 합니다.

스크립트 경로 결정 순서:
1. `$CLAUDE_PLUGIN_ROOT` 가 설정되어 있으면 `"$CLAUDE_PLUGIN_ROOT/scripts/copy-standup-to-clipboard.py"` 사용
2. 아니면 `git rev-parse --show-toplevel` 결과로 `<repo>/plugins/jira/scripts/copy-standup-to-clipboard.py` 구성
3. 둘 다 실패하면 사용자에게 "스크립트 경로를 찾을 수 없습니다"로 보고하고 Step 5 포기 (임의로 추측 금지)

실행 예 (실제 리포트 내용으로 본문을 채워야 함):

```bash
python3 "${CLAUDE_PLUGIN_ROOT:-$(git rev-parse --show-toplevel)/plugins/jira}/scripts/copy-standup-to-clipboard.py" <<'STANDUP_EOF'
어제 한 업무는 무엇인가요?
어제 한 업무
  - SEARCH-13040 [BE] product-traits-v4 — 기존 단일 메인 인덱스 제거 (Phase 2)



오늘 할 일을 적어보아요
- SEARCH-13037 리뷰 색인 실패 수정 요청
STANDUP_EOF
```

**결과 확인:**
- 스크립트는 성공 시 `Copied standup to clipboard (HTML + plain). Paste into Slack.` 출력, 종료 코드 0.
- 비정상 종료(stdin 비어있음, osascript 실패)는 stderr에 에러 표시 후 비-0 종료 — 이 경우 사용자에게 에러를 그대로 전달.
- 스크립트가 클립보드에 `public.html` + `public.utf8-plain-text`를 동시 세팅하므로, Slack 메시지창에 `Cmd+V` 하면 `SEARCH-*` 이슈 키가 자동 하이퍼링크됨.
- Jira base URL은 스크립트 상수(`JIRA_BASE`)에 하드코딩 — 조직이 다르면 스크립트 파일을 직접 수정.

---

## Edge Cases

### 어제 한 일이 없을 때

Done 이슈가 없거나 사용자가 아무것도 선택하지 않으면:

```
어제 한 업무
  (없음)
```

### 오늘 할 일이 없을 때

In Progress 이슈가 없고 Backlog에서도 선택하지 않으면:

```
오늘 할 일을 적어보아요
(없음)
```

### Jira 연결 정보가 없을 때

`getAccessibleAtlassianResources`로 cloudId를 먼저 조회한 후 진행.
