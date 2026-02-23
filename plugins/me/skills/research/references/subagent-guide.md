# Subagent Strategy Guide

## Why Subagents?

Research benefits from subagent delegation:

- **Fresh context** per research question (no contamination)
- **Parallel execution** of independent research tracks
- **Cost efficiency** using Haiku for focused tasks
- **Focused scope** reduces confusion and improves accuracy

## Model Selection

| Task Type | Model | Rationale |
| :--- | :--- | :--- |
| Codebase exploration | **haiku** (Explore agent default) | Fast, cheap, sufficient for code search |
| Web research | **haiku** (web-researcher agent) | Quick information gathering |
| Complex synthesis | **sonnet** (main session) | Analysis requires deeper reasoning |
| Verification requiring execution | **sonnet** | May need to run code/analyze |

**Rule of thumb:** Use Haiku for subagent research tasks. Reserve Sonnet for final synthesis and complex verification.

## Research Scenarios and Tool Selection

| Scenario | Tool Command | Model | When to Use |
| :--- | :--- | :--- | :--- |
| **Codebase-only** | `Task tool: subagent_type="Explore"` | haiku | Unfamiliar architecture, existing bugs, code patterns |
| **Web-only** | `Task tool: subagent_type="me:web-researcher"` | haiku | New tech, official docs, version-specific info |
| **Hybrid** | Parallel: Explore + web-researcher | haiku (both) | Code vs docs comparison, version mismatches |

## Tool Usage Guidelines

### For Codebase Research

**DO:**

```markdown
Task tool with subagent_type="Explore", description="Search codebase for X implementation patterns"
```

**DON'T:**

- Use Grep/Glob directly for exploration (slow, single-source)
- Use Explore agent for web search (it has no web tools)
- Use general-purpose agent when Explore is specialized for codebase

### For Web Research

**DO:**

```markdown
Task tool with subagent_type="me:web-researcher", description="Find official documentation for X framework"
```

**DON'T:**

- Use built-in WebSearch tool (use web-researcher agent instead)
- Skip version context (always specify version when relevant)
- Rely on single source (web-researcher will cross-reference)

### For Hybrid Research (Parallel Pattern)

When you have independent codebase AND web research questions:

```markdown
# Define independent scopes
Subtask A: "How is authentication implemented in our codebase?"
Subtask B: "What are the official authentication patterns for Framework X?"

# Dispatch in parallel (use Task tool in single message with multiple Task calls)
Task 1: subagent_type="Explore", description="Search codebase for authentication implementation"
Task 2: subagent_type="me:web-researcher", description="Find Framework X official authentication patterns"

# Synthesize findings
Compare: Our implementation vs official docs
Identify: Gaps, anti-patterns, version mismatches
```

## Subagent Anti-patterns

- "I'll search myself" → Use subagents for research. You synthesize.
- "Sequential is fine" → Independent research = parallel execution.
- "Sonnet for everything" → Haiku sufficient for focused research tasks.
- "Explore agent can search web" → Explore has NO web tools.
- "mgrep is just for search" → mgrep --web --answer provides synthesis.
- "General-purpose is safer" → Specialized agents (Explore, web-researcher) are more focused.
