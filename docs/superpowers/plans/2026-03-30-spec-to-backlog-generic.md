# spec-to-backlog: Remove Confluence Dependency Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `spec-to-backlog` skill work with any spec input (markdown, free text, conversation context) instead of requiring a Confluence page.

**Architecture:** Replace the Confluence-specific Step 1 with a generic "obtain spec content" step that handles: (1) content already in conversation context, (2) user-provided markdown/text, (3) missing content → ask user. Remove all Confluence tool calls and links from Epic/Task description templates.

**Tech Stack:** Markdown (SKILL.md edit only)

---

### Task 1: Update SKILL.md frontmatter and overview

**Files:**
- Modify: `plugins/jira/skills/spec-to-backlog/SKILL.md`

- [ ] **Step 1: Update frontmatter `description`**

Change line 3 from:
```
description: "Automatically convert Confluence specification documents into structured Jira backlogs with Epics and implementation tickets. When Claude needs to: (1) Create Jira tickets from a Confluence page, (2) Generate a backlog from a specification, (3) Break down a spec into implementation tasks, or (4) Convert requirements into Jira issues. Handles reading Confluence pages, analyzing specifications, creating Epics with proper structure, and generating detailed implementation tickets linked to the Epic."
```

To:
```
description: "Convert specifications into structured Jira backlogs with Epics and implementation tickets. When Claude needs to: (1) Create Jira tickets from a spec, requirements doc, or conversation, (2) Generate a backlog from a specification, (3) Break down a spec into implementation tasks, or (4) Convert requirements into Jira issues. Handles analyzing specifications from any source (markdown, free text, conversation context), creating Epics with proper structure, and generating detailed implementation tickets linked to the Epic."
```

- [ ] **Step 2: Update Overview paragraph**

Change:
```
Transform Confluence specification documents into structured Jira backlogs automatically. This skill reads
requirement documents from Confluence, intelligently breaks them down into logical implementation tasks,
**creates an Epic first** to organize the work, then generates individual Jira tickets linked to that Epic -
eliminating tedious manual copy-pasting.
```

To:
```
Transform specifications into structured Jira backlogs automatically. This skill reads requirement
documents from any source — markdown files, free text, or conversation context — intelligently breaks
them down into logical implementation tasks, **creates an Epic first** to organize the work, then
generates individual Jira tickets linked to that Epic - eliminating tedious manual copy-pasting.
```

- [ ] **Step 3: Commit**

```bash
git add plugins/jira/skills/spec-to-backlog/SKILL.md
git commit -m "feat(jira): update spec-to-backlog description to remove Confluence dependency"
```

---

### Task 2: Replace Step 1 (Confluence fetch → generic spec input)

**Files:**
- Modify: `plugins/jira/skills/spec-to-backlog/SKILL.md`

- [ ] **Step 1: Replace the entire "Step 1: Fetch Confluence Page" section**

Remove from `## Step 1: Fetch Confluence Page` through the closing `---` (lines ~19–69).

Replace with:

```markdown
## Step 1: Obtain Specification Content

Determine where the specification content comes from before proceeding.

### If spec content is already in the conversation

The user may have pasted markdown, free text, a requirements doc, or described the feature in
the conversation. If there is enough content to analyze, proceed directly to Step 3.

### If the user referenced a file path or URL

Read the file directly if it is accessible. For a local markdown file, read its contents and
proceed to Step 3.

### If spec content is missing or unclear

Ask the user to provide the specification:

> "Please share the specification content — you can paste markdown, free text, or describe the
> feature you want to break down into Jira tickets."

Wait for the user's response, then proceed to Step 3.

---
```

- [ ] **Step 2: Update Core Workflow step 1 label**

In the `## Core Workflow` section, change:
```
1. **Fetch Confluence Page** -> Get the specification content
```
To:
```
1. **Obtain Spec Content** -> Get the specification content from context, file, or user
```

- [ ] **Step 3: Commit**

```bash
git add plugins/jira/skills/spec-to-backlog/SKILL.md
git commit -m "feat(jira): replace Confluence fetch step with generic spec input in spec-to-backlog"
```

---

### Task 3: Remove Confluence links from Epic and Task description templates

**Files:**
- Modify: `plugins/jira/skills/spec-to-backlog/SKILL.md`

- [ ] **Step 1: Update Epic Description Structure**

In the `### Epic Description Structure` section, remove the `## Source` block:

Remove:
```
## Source
Confluence Spec: [Link to Confluence page]
```

The section should go directly from `## Overview` to `## Objectives`.

- [ ] **Step 2: Update Task Description Structure**

In the `### Task Description Structure` section, update `## Related`:

Change:
```
## Related
- Confluence Spec: [Link to relevant section if possible]
- Epic: PROJ-123
```

To:
```
## Related
- Epic: PROJ-123
```

- [ ] **Step 3: Commit**

```bash
git add plugins/jira/skills/spec-to-backlog/SKILL.md
git commit -m "feat(jira): remove Confluence links from Epic and Task description templates"
```

---

### Task 4: Update edge cases and examples to remove Confluence references

**Files:**
- Modify: `plugins/jira/skills/spec-to-backlog/SKILL.md`

- [ ] **Step 1: Update "Multiple Specs or Pages" edge case title and text**

Change heading:
```
### Multiple Specs or Pages
```
To:
```
### Multiple Specs
```

Change the example quote:
```
"I see you've provided 3 spec documents. Should I create separate Epics for each, or would you like me to
  focus on one first?"
```
To:
```
"I see you've provided content for 3 different features. Should I create separate Epics for each, or would you like me to focus on one first?"
```

- [ ] **Step 2: Verify no remaining Confluence references**

Search the file for any remaining occurrences of "Confluence", "confluence", "getConfluencePage", or "atlassian.net/wiki":

```bash
grep -n -i "confluence\|getConfluencePage\|atlassian.net/wiki" plugins/jira/skills/spec-to-backlog/SKILL.md
```

Expected output: no matches. If any remain, remove or generalize them.

- [ ] **Step 3: Commit**

```bash
git add plugins/jira/skills/spec-to-backlog/SKILL.md
git commit -m "feat(jira): remove remaining Confluence references from spec-to-backlog"
```
