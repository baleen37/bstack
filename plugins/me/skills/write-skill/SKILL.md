---
name: write-skill
description: Use when creating or improving an agent skill, writing a SKILL.md or its description, fixing a skill that triggers too rarely or too often, or tuning one with SkillOpt or SkillOpt-Sleep from benchmark tasks or provider session history.
---

# Write Skills

Write the smallest SKILL.md that changes behavior. Most skills are one file
with two frontmatter fields and a short body.

```yaml
---
name: my-skill            # lowercase-hyphens, matches the directory name
description: Use when ... # third person, names the trigger, <=1024 chars
---
```

The description is the whole trigger mechanism — it is all the model sees
before deciding to load the skill. Say when to use it, using the words someone
would actually type, and cover both failure directions ("triggers too rarely or
too often", not just one). Never write "I help you..." .

For the body: include only what the model gets wrong without you. It knows the
domain; it does not know your conventions or the traps. Cut anything else — a
skill that restates common knowledge changes no behavior and costs context
every session. Keep it under 500 lines, and write rules that hold for the whole
task rather than one-time steps, because the body is injected once and never
re-read.

Split to `references/` only what a subset of runs needs, link it one level deep
from here, and say what is in it so the agent knows whether to open it.

## Prove it works

Skip this and you are guessing. A new skill's baseline is the same task with no
skill at all.

1. Write 3+ tasks that show the failure, with a checkable success signal.
2. Run them with no skill. That is the baseline.
3. Write the smallest thing that fixes it.
4. Re-run. Keep it only if it beats baseline.

If baseline already passes, do not write the general skill — say so. Then look
for what the model cannot derive: your environment's facts, your conventions,
the traps it knows in theory but misses under pressure. Either narrow the skill
to that and re-test, or report that no skill is warranted. A skill that restates
what baseline already did is pure context cost.

Match the testing to the stakes. A one-screen skill deserves a trigger check and
one real task, not seven subagents.

Test the description separately: give a subagent the frontmatter only, with 5
prompts that should trigger and 4 that should not.

Asking a fresh agent "what did you have to guess?" tells you what to add, so it
only ever grows the file. Use it to find gaps, then use step 4 to decide which
gaps were worth filling.

## When it does not trigger

Malformed YAML is the usual cause and it hides well: the body still loads with
empty metadata, so `/skill-name` works while auto-triggering never does.
`--debug` shows the parse error.

If the description looks truncated, the skill listing budget is full. It is 1%
of the context window and drops least-used skills first; raise
`skillListingBudgetFraction` or set noisy skills to `"name-only"` in
`skillOverrides`. `/doctor` shows the worst offenders.

If it fires when it should not, narrow the description or set
`disable-model-invocation: true`.

## Where it goes

`.claude/skills/<name>/SKILL.md` for one checkout, `<plugin>/skills/<name>/`
for a repo that ships skills as a plugin. Prefer the plugin path in this repo;
ask if both could apply. Confirm any other harness's path from its own docs.

Show the diff before changing a skill that is already in use. A new file needs
no diff.

## SkillOpt

Ignore this section unless SkillOpt or SkillOpt-Sleep came up. It automates the
loop above by mining tasks from past sessions and gating the edit on a held-out
split.

**If it did come up, read [references/skillopt.md](references/skillopt.md)
before writing a single command or step.** Its flags, transcript scoping, and
merge format are not what they appear to be, and answers from memory are wrong
in ways that fail silently — `--source auto` skips a provider, `--scope invoked`
pulls in unrelated sessions, and concatenating task files destroys provenance.
Do not describe a procedure, name a flag, or say what is supported until you
have read that file.
