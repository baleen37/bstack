---
name: slack-messaging
description: Draft, format, and send Slack messages through the official Slack MCP server.
---

# Slack Messaging

Use the official Slack MCP server configured by this plugin.

## Workflow

1. Confirm the target channel, DM, or thread before writing.
2. Draft the exact message first when the request could affect other people.
3. Keep messages concise, concrete, and suited to Slack scanning.
4. Preserve thread context: reply in-thread unless the user asks for a channel broadcast.
5. For status updates, include owner, current state, blocker, and next action.

## Safety

- Do not post, edit, or delete without a clear user request.
- Avoid accidental mentions such as `@channel` or `@here` unless explicitly requested.
- Do not expose private Slack content in a new destination without permission.
