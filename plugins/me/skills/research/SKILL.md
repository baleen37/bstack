---
name: research
description: Use when exploring unfamiliar codebases, investigating bugs, checking external documentation, or learning unfamiliar technology before acting
---

# Research

Investigate at the shallowest depth that answers safely, then stop: **Observe → Explore → Verify**.

1. **Observe** — read the cheapest orienting source first (CLAUDE.md, README, the one named file). Name what you *don't* yet know.
2. **Explore** — answer the open questions. Do it directly only when it's shallow; otherwise delegate (below).
3. **Verify** — close the loop once: run it, trace the call, or cross-check a second source before you act on the finding.

## Delegate Wide Research to a Subagent

Orient first (the one cheap read), **then** decide — orientation often shrinks a "wide" question to a one-file answer, so don't delegate before you've looked.

Once oriented, if what's still open would read several files or sources — code, web, or both — **delegate to `Agent: subagent_type="me:researcher"`.** Its context absorbs the dead ends; you get only the summary, keeping the main context clean.

Do it yourself only when delegation overhead isn't worth it:

| What's left open | Do |
| :--- | :--- |
| One named file / known symbol | Direct `Read` / `grep` / LSP — you can cite file:line in a step or two |
| Behavior claim, runnable locally | Reproduce with a command or test yourself |
| Wide/unknown code, web docs, or a mix | Delegate to `me:researcher` |

Dispatch **independent research in one message** — several `me:researcher` calls (or a direct read alongside one) run concurrently. Only go sequential when a call needs the previous result. Match the agent count to the question's real branches — one subagent per genuinely independent sub-question, not per file. Each spins up a fresh context, so over-splitting burns tokens for no extra signal. Give each subagent one objective and the exact fields you want back.

## Evidence Standards

- Match evidence depth to risk; quick lookups need one cited source.
- Bug causes, recommendations, comparisons, and external facts want 2-3 *independent* signals — static config and runtime artifact count as two; two reads of the same file do not.
- Behavior claims need observed output, not code reading alone.
- Test the premise, not just the question — the report ("X is broken") may itself be false; check the actual state.
- Negative evidence is evidence: say where you searched and what was absent.

## Stop When

The next search won't change your decision. You have a citable answer at the depth the risk demands. Beyond that, more reading is confirmation, not signal.

## Red Flags — STOP

- 3-source research for a file-location question.
- Reading file after file in the main context when `me:researcher` should absorb that work.
- Dispatching subagents one per message when several are independent.
- Fanning out more subagents than the question has independent branches — context spin-up is the cost, not the search.
- Claiming behavior from code when a runnable check exists.
- Reading code for a live URL/UI bug before inspecting the running page (`me:browse`).
- Trusting outdated or unsourced web content.
