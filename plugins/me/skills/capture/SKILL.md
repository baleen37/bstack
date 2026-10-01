---
name: capture
description: Save something worth keeping from this session as a note in the user's Obsidian inbox, `~/wiki/Inbox/`.
argument-hint: "What should be captured?"
disable-model-invocation: true
---

# Capture

Turn what the user wants to keep into one note they will read again later. A
note is a **promotion**, not a copy: the distilled insight, not the transcript
or the agent's working state.

**Save to:** `~/wiki/Inbox/<title>.md`

- The inbox is flat and shared with other notes. Never create subdirectories,
  and never edit or delete a file you did not create in this run.
- If the file already exists, pick a different title. Never overwrite.
- Do not commit. The vault has its own backup.

## What to capture

If the user named it, capture that. Otherwise propose up to three candidates
from this session, one line each, and let the user pick. Do not write before
they choose.

One note holds one idea. If the user's request covers two, write two notes.

## Title

A descriptive title the user would search for, in the language they use.

When capturing from a `me:learn` workspace (`~/.bstack/learn/<topic>/`), use
`LR; <topic> - <title>`, so every note from one topic sorts together.

## Note format

```md
---
created: YYYY-MM-DD
tags:
---

{The insight, in 1-5 short paragraphs. Lead with the claim, then why it holds.}

## Sources

- {Link to the primary source, or the file/command it came from.}
```

- Write for a reader who has forgotten this session. No "as discussed above".
- Keep only what is non-obvious. If the note restates a definition the user
  could look up in ten seconds, cut it.
- Omit `## Sources` only when there is genuinely nothing to cite.
- Use `[[wikilinks]]` only for notes you have confirmed exist in `~/wiki/`.

## Finish

Report the path of each note written.
