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

### Step 1: Fetch Jira Issues

Run three queries in parallel:

**Query A — 어제 한 일** (assignee, recently updated, active statuses):

```jql
assignee = currentUser() AND status IN ("In Progress", "Done") AND updated >= -1d ORDER BY updated DESC
```

**Query B — 오늘 할 일** (currently in progress):

```jql
assignee = currentUser() AND status = "In Progress" ORDER BY updated DESC
```

**Query C — 참고용 Backlog** (upcoming work, top 10):

```jql
assignee = currentUser() AND status = "Backlog" ORDER BY updated DESC
```

Use `maxResults: 20` for A and B, `maxResults: 10` for C.

Fields to fetch: `["summary", "status", "updated", "key"]`

---

### Step 2: Show Backlog and Ask for Today's Plan

Present the Backlog items as a numbered list and ask if any should be added to "오늘 할 일":

```
참고용 Backlog (최근 업데이트 순):
1. SEARCH-12563 Slow path signal 증분 처리 구조 전환
2. SEARCH-12255 기등록된 검매핑에 대해 모델 파라미터로 상쇄 처리 기능 필요
...

오늘 할 일에 추가할 항목이 있나요? (번호로 답하거나 없으면 엔터)
```

Wait for user response. Add selected items to the "오늘 할 일" list.

---

### Step 3: Ask for Blocker and Insight

Ask in a single message:

```
도움(Risk/Blocker)이 필요한 사항이 있나요?
공유하고 싶은 인사이트가 있나요?
(없으면 엔터)
```

Wait for user response.

---

### Step 4: Output the Standup Report

Format and print the final report using the template in `references/standup-template.md`.

- 어제 한 일: Query A 결과
- 오늘 할 일: Query B 결과 + 사용자가 추가한 Backlog 항목
- 나머지 섹션: 사용자 입력값, 없으면 빈칸

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
