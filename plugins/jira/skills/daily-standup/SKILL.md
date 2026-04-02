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
