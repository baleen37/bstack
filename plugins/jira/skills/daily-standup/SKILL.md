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

Before querying, calculate the previous workday based on today's day of week:

- **Monday** → use `-3d` (Friday)
- **Tuesday–Friday** → use `-1d` (yesterday)
- **Saturday/Sunday** → use `-1d` (treat as normal, unlikely to run standup on weekends)

Use the `currentDate` from context or system to determine today's day of week.

### Step 2: Fetch Jira Issues

Run three queries in parallel using the lookback period from Step 1 (`{LOOKBACK}`):

All queries must exclude Epic issue type: add `AND issuetype != Epic` to every JQL.

**Query A — 어제 한 일 후보** (assignee, recently updated, active statuses, no Epics):

```jql
assignee = currentUser() AND issuetype != Epic AND status IN ("In Progress", "Done") AND updated >= -{LOOKBACK} ORDER BY updated DESC
```

**Query B — 오늘 할 일** (currently in progress, no Epics):

```jql
assignee = currentUser() AND issuetype != Epic AND status = "In Progress" ORDER BY updated DESC
```

**Query C — 참고용 Backlog** (upcoming work, top 10, no Epics):

```jql
assignee = currentUser() AND issuetype != Epic AND status = "Backlog" ORDER BY updated DESC
```

Use `maxResults: 20` for A and B, `maxResults: 10` for C.

Fields to fetch: `["summary", "status", "updated", "key"]`

---

### Step 3: Ask User to Select Yesterday's Work

Query A returns candidates — the user must confirm which ones they actually worked on.
Present as a numbered list and wait for selection:

```
어제 한 업무 후보 ({이전 업무일} 기준):
1. {ISSUE_KEY} {ISSUE_SUMMARY}
2. {ISSUE_KEY} {ISSUE_SUMMARY}

어제 실제로 작업한 항목을 골라주세요. (번호로 답하거나 전체면 "전체", 없으면 엔터)
```

Wait for user response. Use selected items as "어제 한 일".

Then present Backlog items and ask for today's additions:

```
참고용 Backlog (최근 업데이트 순):
1. {ISSUE_KEY} {ISSUE_SUMMARY}
2. {ISSUE_KEY} {ISSUE_SUMMARY}

오늘 할 일에 추가할 항목이 있나요? (번호로 답하거나 없으면 엔터)
```

Wait for user response. Add selected items to the "오늘 할 일" list.

---

### Step 4: Output the Standup Report

Format and print the final report using the template in `references/standup-template.md`.

- 어제 한 일: 사용자가 Query A에서 선택한 항목
- 오늘 할 일: Query B 결과 + 사용자가 추가한 Backlog 항목

---

## Edge Cases

### 어제 한 일이 없을 때

Query A 결과가 비어있으면 (주말, 휴일 등):

```
어제 한 업무
  (없음)
```

### 오늘 할 일이 없을 때

Query B 결과가 비어있고 사용자가 Backlog에서도 선택하지 않으면:

```
오늘 할 일을 적어보아요
(없음)
```

### Jira 연결 정보가 없을 때

`getAccessibleAtlassianResources`로 cloudId를 먼저 조회한 후 진행.
