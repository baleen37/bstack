# Development Guide

## Adding Components

### Commands

Create `commands/my-command.md`:

```markdown
---
description: What this command does
argument-hint: [required-arg] [optional-arg]
allowed-tools: [Read, Write, Bash]
---

# Command Name

Explanation of what the command does.

## Your task

Step-by-step instructions for Claude.
```

### Agents

Create `agents/my-agent.md`:

```markdown
---
name: my-agent
description: Use when X, Y, or Z. Examples: (1) X, (2) Y.
model: inherit
color: purple
tools: [Read, Grep, Bash]
---

# Agent Name

You are an expert in X.

## Your approach

1. First do this
2. Then do that
```

### Skills

Create `skills/my-skill/SKILL.md`:

```markdown
---
name: my-skill
description: Activates when user asks for X or mentions Y
version: 1.0.0
---

# Skill Name

When this applies and what to do.
```

### Hooks

Update `hooks/hooks.json`:

```json
{
  "hooks": {
    "EventName": [{
      "matcher": "ToolPattern",
      "hooks": [{
        "type": "command",
        "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/script.sh",
        "timeout": 30
      }]
    }]
  }
}
```

## Best Practices

1. **Naming**: Use `lowercase-with-hyphens` for all names
2. **Paths**: Always use `${CLAUDE_PLUGIN_ROOT}` for portability
3. **Descriptions**: Be specific and include examples
4. **Testing**: Add tests for new functionality
5. **Documentation**: Update README with new features

## Running Tests

Run tests before committing:

```bash
# Run all BATS tests
bats tests/

# Run specific test
bats tests/directory_structure.bats
```

## Test Files

| Test File | Purpose |
| --------- | ------- |
| `directory_structure.bats` | Validate plugin structure and required files |
| `marketplace_json.bats` | Validate marketplace.json format and content |
| `plugin_json.bats` | Validate individual plugin.json files |
| `command_files.bats` | Validate command file format and frontmatter |
| `agent_files.bats` | Validate agent file format and frontmatter |
| `skill_files.bats` | Validate skill file format and frontmatter |

## CI/CD

Tests run automatically on:

- Pull requests
- Push to main branch
- Releases

See `.github/workflows/` for workflow definitions.
