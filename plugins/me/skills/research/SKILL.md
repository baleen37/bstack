---
name: research
description: Use when exploring unfamiliar codebases, investigating bugs, checking external documentation, or learning unfamiliar technology before acting
---

# Research

Use the shallowest investigation that can answer safely: **Observe → Explore → Verify → Summarize**.

## Depth Selection

| Need | Use | Stop When |
| :--- | :--- | :--- |
| Quick lookup | Direct `Read`, grep, or LSP | You can cite the exact file/line or source |
| Codebase map | `Agent: subagent_type="Explore"` | Search spans many files, naming variants, or 3+ queries |
| Bug/behavior | Reproduce with a targeted command or test | Execution output and code explain the cause |
| Live UI/page bug | Inspect the running page (`me:browse`) before reading code | You have observed the actual DOM/console/network, not just the source |
| Web/current docs | Context7 first; `Agent: subagent_type="me:web-researcher"` for broader web research | Official or recent sources answer the question |
| Hybrid | Code and web research in parallel | Main session synthesizes both evidence sets |

## Evidence Standards

- Match evidence depth to risk.
- Quick lookups need one cited source.
- Bug causes, recommendations, comparisons, and external facts need 2-3 independent signals when available.
- Behavior claims need observed output, not code reading alone.
- Negative evidence: say where you searched and what was absent.

## Red Flags — STOP

- Doing 3-source research for a simple file-location question.
- Using broad manual search when `Explore` would be faster.
- Calling web research for repo-only questions.
- Claiming behavior from code only when a runnable check exists.
- Treating outdated or unsourced web content as fact.
- Investigating a bug at a live URL/UI by reading code first instead of inspecting the running page.
