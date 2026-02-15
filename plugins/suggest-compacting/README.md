# Suggest Compacting

Suggests when to manually compact context during long Claude Code sessions.

## Overview

Suggest Compacting monitors your editing activity and suggests when to manually run `/compact`. Unlike forced auto-compaction that interrupts at arbitrary moments, this plugin preserves your workflow by providing non-intrusive suggestions at logical intervals.

**Key distinction**: The plugin suggests; you decide when to compact.

## How It Works

The hook tracks Edit/Write tool calls per session and suggests when to compact:
- First suggestion at 50 tool calls (configurable via `COMPACT_THRESHOLD`)
- Subsequent suggestions every 25 calls thereafter
- Non-blocking stderr messages don't interrupt workflows

## Usage

Install via the baleen-plugins marketplace:

```bash
/plugin install suggest-compacting@baleen-plugins
```

## Configuration

Set a custom threshold via environment variable:

```bash
export COMPACT_THRESHOLD=100
```

Default: 50 tool calls

## Messages

When thresholds are reached, you'll see non-intrusive suggestions:

```
[SuggestCompacting] 50 tool calls reached - consider /compact if transitioning phases
[SuggestCompacting] 75 tool calls - good checkpoint for /compact if context is stale
```

## Use Cases

Ideal for:
- Long debugging sessions (compact after finding root cause)
- Multi-phase features (compact after exploration, before implementation)
- Refactoring work (compact after each module)
- Research-to-code transitions (compact before writing code)

## Why Suggestions Over Auto-Compaction?

**Forced auto-compaction problems:**
- Happens at unpredictable points, often mid-task
- Loses critical context during active work
- Interrupts thought processes
- Difficult to resume after compaction

**Suggest Compacting benefits:**
- You control when compaction occurs
- Preserve context through logical phases
- Choose natural breakpoints in your workflow
- Maintain continuity of work

## Repository

Part of the [dotfiles](https://github.com/baleen37/dotfiles) project - Nix flakes-based reproducible development environments for macOS and NixOS.
