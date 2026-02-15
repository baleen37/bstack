---
name: review-claudemd
description: Diagnose problems in the current conversation and suggest improvements to CLAUDE.md and skills.
disable-model-invocation: true
allowed-tools: Read, Glob, Grep
---

# Review Claude Configuration

Analyze the **current conversation** to diagnose problems and suggest improvements across two areas: CLAUDE.md and Skills.

This is a diagnostic tool. It looks at what just happened and finds what's broken or missing.

## What This Skill Does

Review the current conversation and identify:

1. **CLAUDE.md issues** — rules violated, missing rules, unclear rules, outdated rules
2. **Skill issues** — skills that should have been used but weren't, skills that were used incorrectly, skills that are missing and should be created (skills subsume slash commands)

## Process

### Step 0: Ask what to review

If the user didn't specify a scope, ask using AskUserQuestion:

- **Question:** "What would you like to review?"
- **Options:**
  1. **All** — diagnose both CLAUDE.md and Skills
  2. **CLAUDE.md** — violated, missing, or unclear rules
  3. **Skills** — missed, inadequate, or missing skills

If the user already specified (e.g., "review skills", "CLAUDE.md 개선"), skip this step and go directly to the relevant section.

### Step 1: Read current configuration

Read in parallel:
- Global CLAUDE.md: `~/.claude/CLAUDE.md`
- Local CLAUDE.md: `./CLAUDE.md` (if exists)
- All available skills: scan `skills/*/SKILL.md` in both the project and any installed plugins

Only read what's relevant to the selected scope.

### Step 2: Analyze current conversation

You have access to the full current conversation. Analyze it for:

**CLAUDE.md diagnosis:**
- Rules that exist but were violated → need stronger wording or restructuring
- Patterns that kept repeating but aren't codified → need new rules
- Rules that caused confusion or were misinterpreted → need clearer wording
- Rules that were irrelevant or got in the way → candidates for removal

**Skill diagnosis:**
- Moments where a skill should have been invoked but wasn't
- Skills that were invoked but didn't help (wrong skill, or skill content was inadequate)
- Workflows that came up organically and should be captured as a new skill
- Existing skills with gaps or outdated instructions
- Repetitive actions that should be a skill (skills replace slash commands)

### Step 3: Present findings

Output a report with two sections. For each finding, be specific — cite the exact moment in the conversation or the exact rule/skill involved.

```markdown
## CLAUDE.md

### Violated Rules
- [rule] — violated when [specific moment]. Suggestion: [rewording or restructuring]

### Missing Rules
- [pattern observed] — should be added to [global/local] CLAUDE.md because [reason]

### Unclear or Outdated Rules
- [rule] — caused [confusion/was irrelevant]. Suggestion: [fix or remove]

## Skills

### Missed Skills
- [skill name] should have been used when [moment] — wasn't invoked because [reason]

### Inadequate Skills
- [skill name] — failed to help because [gap]. Suggestion: [improvement]

### Missing Skills
- [workflow observed] — should be a new skill because [it would help with X]
```

### Step 4: Ask user what to implement

Present the findings and ask which improvements to draft. Don't edit files without approval.

## Key Principles

- **Current conversation only** — don't parse jsonl files. You already have the context.
- **Specific, not vague** — "rule X was violated at moment Y" not "some rules could be improved"
- **Actionable** — every finding should have a concrete suggestion
- **Honest** — if the conversation went well and nothing is broken, say so. Don't manufacture findings.
