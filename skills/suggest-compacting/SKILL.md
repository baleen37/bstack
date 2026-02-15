---
name: suggest-compacting
description: Suggests manual /compact at logical intervals during long sessions
---

# Suggest Compacting

Suggests when to manually compact context during long Claude Code sessions.

**Core principle**: The plugin suggests; you decide when to compact.

## When to Use

Suggest Compacting is automatically active during long sessions with significant file editing activity.

**Automatic activation criteria:**
- After 50 Edit/Write tool calls (default threshold)
- Every 25 calls after threshold
- Configurable via `COMPACT_THRESHOLD` environment variable

**Manual activation:**
- When you notice context becoming stale
- Before starting new implementation phase
- After completing major milestones

## How It Works

The Suggest Compacting hook tracks file editing activity:

1. **Session-based tracking**: Counts Edit/Write tool calls per session
2. **Persistent state**: Counter persists via `~/.claude/suggest-compacting/tool-count-{session_id}.txt`
3. **Non-blocking suggestions**: Shows stderr messages that don't interrupt workflow
4. **Session isolation**: Each Claude Code session has its own counter

### Messages You'll See

At threshold (default: 50):
```
[SuggestCompacting] 50 tool calls reached - consider /compact if transitioning phases
```

Every 25 calls after threshold:
```
[SuggestCompacting] 75 tool calls - good checkpoint for /compact if context is stale
```

## Best Practices

### When to Compact

**Good timing:**
- After exploration phase, before implementation
- After completing a milestone (feature, bugfix, refactor)
- Before starting new unrelated task
- When context feels stale or repetitive
- After debugging, before writing fix

**Bad timing:**
- Mid-implementation of current task
- Before understanding the problem
- When actively debugging
- During code review feedback

### Compaction Strategy

**What to keep:**
- Current task context and requirements
- Relevant architectural decisions
- Recent test results
- Current debugging findings

**What to summarize:**
- Completed implementation details
- Historical conversation not relevant to current task
- Explored alternatives not chosen
- Past debugging attempts

### Workflow Integration

1. **Exploration phase**: Read code, understand problem
2. **Compact**: `/compact` - summarize findings, preserve context
3. **Implementation phase**: Write code, test
4. **Compact**: `/compact` - preserve implementation context
5. **Next phase**: Repeat as needed

## Configuration

### Custom Threshold

Set `COMPACT_THRESHOLD` to customize when suggestions appear:

```bash
# In your shell profile or session
export COMPACT_THRESHOLD=100  # Suggest after 100 tool calls
```

Default: 50 tool calls

### State Directory

Session counters stored in:
```
~/.claude/suggest-compacting/tool-count-{session_id}.txt
```

Session ID extracted from SessionStart hook and stored in:
```
~/.claude/suggest-compacting/session-env.sh
```

## Why Suggestions Over Forced Auto-Compaction?

**Forced auto-compaction problems:**
- Happens at arbitrary points, often mid-task
- Loses critical context during active work
- Interrupts thought processes
- Difficult to resume after compaction

**Suggest Compacting benefits:**
- You control when compaction occurs
- Preserve context through logical phases
- Choose natural breakpoints
- Maintain continuity of work

## Use Cases

### Long Debugging Sessions
1. Explore symptoms and reproduce bug
2. **Compact** (after finding root cause)
3. Implement fix
4. Test and verify

### Multi-Phase Features
1. Research and design
2. **Compact** (after exploration)
3. Implementation phase 1
4. **Compact** (after milestone)
5. Implementation phase 2

### Refactoring Work
1. Analyze current code
2. **Compact** (after understanding)
3. Refactor module A
4. **Compact** (after module A)
5. Refactor module B

### Research-to-Code Transitions
1. Research problem domain
2. **Compact** (before writing code)
3. Implement solution

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Compacting mid-implementation | Wait for natural breakpoints |
| Compacting too frequently | Use 50-call threshold as guide |
| Not compacting at all | Context becomes stale, performance degrades |
| Compacting without summarizing | Preserves wrong context |

## Quick Reference

| Activity | Tool Calls | Action |
|----------|-----------|--------|
| Initial exploration | 0-50 | Continue normally |
| Threshold reached | 50 | Consider /compact if transitioning |
| Implementation | 50-100 | Check context at 75 |
| Milestone complete | 100+ | /compact before next phase |

## Integration with Other Tools

Suggest Compacting works well with:
- **Git workflows**: Compact before committing
- **TDD**: Compact after red-green-refactor cycle
- **Code review**: Compact after implementing feedback
- **Documentation**: Compact before writing docs
