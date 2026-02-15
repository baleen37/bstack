# Jira Plugin

Jira integration plugin for Claude Code with intelligent issue tracking, task automation, and project management workflows.

## Purpose

Enables seamless Jira integration through Atlassian's official MCP server with OAuth 2.1 authentication. Automates common workflows like bug triage, meeting task capture, status reporting, and specification-to-backlog conversion.

## Features

- **OAuth 2.1 Authentication**: Secure authentication through Atlassian's official MCP server
- **Intelligent Bug Triage**: Automatically search for duplicates, analyze fix history, and create well-structured bug reports
- **Meeting Task Capture**: Extract action items from meeting notes and create Jira tasks with proper assignees
- **Status Report Generation**: Query Jira issues and generate formatted reports for different audiences
- **Company Knowledge Search**: Search Jira issues and history for internal documentation and decisions
- **Spec to Backlog Conversion**: Transform Confluence specifications into structured Jira backlogs with Epics and tickets

## Skills

### `triage-issue`

Intelligently triage bug reports and error messages by searching for duplicates in Jira and offering to create new issues or add comments to existing ones.

**When to use:**
- "Triage this error: Connection timeout on mobile login"
- "Has this bug been reported before?"
- "Check if this is a duplicate issue"

**What it does:**
1. Extracts key information from bug reports (error signatures, context, symptoms)
2. Searches Jira for similar or duplicate issues using multiple query strategies
3. Analyzes search results to determine if duplicate or new issue
4. Presents findings with recommendations
5. Creates new bug ticket or adds comment to existing issue based on user decision

**Example:**
```
User: Triage this error - "NullPointerException in PaymentProcessor.processRefund() line 245"

Claude:
- Searches Jira for "NullPointerException", "PaymentProcessor", "refund"
- Finds PROJ-789 (resolved, similar but different line)
- Recommends creating new issue with reference to PROJ-789
- Creates well-structured bug ticket with context
```

---

### `capture-tasks-from-meeting-notes`

Analyze meeting notes to find action items and create Jira tasks for assigned work.

**When to use:**
- "Create tasks from these meeting notes"
- "Extract action items from the standup notes"
- "Turn these action items into Jira tickets"

**What it does:**
1. Fetches meeting notes from Confluence URL or accepts pasted text
2. Parses action items with assignees using multiple patterns (@mentions, "Name to", "Action:", TODO format)
3. Looks up Jira account IDs for assignees
4. Presents parsed action items for user confirmation
5. Creates Jira tasks with proper context and links to source

**Supported action item patterns:**
- `@Sarah to create user stories`
- `Mike will update architecture doc`
- `Action: Lisa - review mockups`
- `TODO: Create report (John)`

---

### `generate-status-report`

Generate project status reports from Jira issues with optional Confluence publishing.

**When to use:**
- "Generate a status report for Project Phoenix"
- "Create a weekly update for the engineering team"
- "What's the status of blocked issues?"

**What it does:**
1. Identifies scope (project, time period, audience)
2. Queries Jira for completed, in-progress, and blocked issues
3. Analyzes data for metrics and key insights
4. Formats report based on audience (Executive, Team, Daily)
5. Presents report with option to publish to Confluence

**Report types:**
- **Executive Summary**: High-level metrics, highlights, blockers (1-2 pages)
- **Team-Level**: Detailed breakdown with issue-by-issue status
- **Daily Standup**: Brief update on yesterday/today/blockers

---

### `search-company-knowledge`

Search Jira to find and explain internal concepts, processes, and technical details through issues and comments.

**When to use:**
- "What are Stratus minions?"
- "How does our deployment process work?"
- "Find information about the billing system"

**What it does:**
1. Identifies search query from user question
2. Searches Jira issues using JQL text search
3. Fetches detailed content from relevant issues
4. Synthesizes results with proper source attribution
5. Highlights discrepancies or conflicting information

**Best for:**
- Finding internal documentation stored in Jira
- Understanding past decisions and their rationale
- Looking up technical details about systems

---

### `spec-to-backlog`

Convert Confluence specification documents into structured Jira backlogs with Epics and implementation tickets.

**When to use:**
- "Create backlog from this Confluence spec"
- "Break down this feature spec into Jira tickets"
- "Generate implementation tasks from the requirements doc"

**What it does:**
1. Fetches Confluence page with specification content
2. Asks for target Jira project
3. Analyzes specification and breaks down into logical tasks
4. Presents breakdown (Epic + tickets) for user confirmation
5. Creates Epic first, then child tickets linked to Epic

**Task breakdown principles:**
- 3-10 tasks per spec (avoids over-granularity)
- Covers backend, frontend, testing, documentation
- Intelligent issue type selection (Story for features, Bug for fixes, Task for infrastructure)

---

## Installation

The plugin uses Atlassian's official MCP server and requires no additional dependencies.

### Step 1: Enable the Plugin

Add the plugin to your Claude Code configuration:

```bash
# If using the claude-plugins monorepo, the plugin is auto-discovered
# Otherwise, copy the plugins/jira directory to your plugins folder
```

### Step 2: First-Time Authentication (OAuth 2.1)

When you first use any Jira-related skill, Claude Code will initiate the OAuth 2.1 authentication flow:

1. **Automatic Prompt**: Claude Code will display an authentication URL
2. **Browser Redirect**: Click the URL to open Atlassian's login page
3. **Authorize Access**: Log in to your Atlassian account and authorize Claude Code
4. **Automatic Completion**: Authentication completes automatically - return to Claude Code

The OAuth 2.1 flow is handled entirely by Atlassian's MCP server at `https://mcp.atlassian.com/v1/mcp`. Your credentials are never stored locally.

### Step 3: Verify Connection

After authentication, verify the connection works:

```
User: "What Jira projects can I access?"

Claude will use the search functionality to list your accessible projects.
```

## Required Permissions

The plugin requires the following Jira permissions:

### Read Permissions
- **Browse Projects**: View projects and issues
- **View Issues**: Read issue details, comments, and history

### Write Permissions
- **Create Issues**: Create new bugs, tasks, stories, and epics
- **Edit Issues**: Update issue fields and descriptions
- **Add Comments**: Comment on existing issues
- **Assign Issues**: Assign issues to team members
- **Transition Issues**: Move issues through workflow states

### Confluence Permissions (Optional)
- **View Pages**: Read Confluence pages for spec-to-backlog and meeting notes
- **Create Pages**: Publish status reports to Confluence
- **Edit Pages**: Update existing Confluence pages

**Note**: Contact your Jira administrator if you need additional permissions for specific projects.

## MCP Server Configuration

The plugin connects to Atlassian's official MCP server:

```json
{
  "atlassian": {
    "type": "http",
    "url": "https://mcp.atlassian.com/v1/mcp"
  }
}
```

This configuration is already set in `.mcp.json` and requires no manual setup.

## Troubleshooting

### Authentication Issues

**Problem**: "Authentication required" or "Unauthorized" errors

**Solutions:**
1. The OAuth flow may have expired - initiate a new Jira request to trigger re-authentication
2. Check that your Atlassian account has access to the required Jira sites
3. Ensure browser cookies are not blocking the OAuth redirect

### Permission Errors

**Problem**: "Permission denied" when creating issues or accessing projects

**Solutions:**
1. Verify your account has the required project permissions (see Required Permissions)
2. Check if the project key is correct
3. Contact your Jira administrator to request additional permissions

### User Lookup Failures

**Problem**: Cannot find user when trying to assign tasks

**Solutions:**
1. Try the full name instead of first name only
2. Check if the user has a Jira account in your organization
3. Create the task unassigned and assign manually in Jira

### No Search Results

**Problem**: Search returns no results when issues exist

**Solutions:**
1. Try different search terms or variations
2. Remove some keywords to broaden the search
3. Check if the issues are in a different project
4. Verify you have browse permissions for the project

### Issue Creation Failures

**Problem**: "Required field missing" when creating issues

**Solutions:**
1. The project may have custom required fields
2. Claude will prompt for missing required fields
3. Provide the requested values to complete creation

### Confluence Page Not Found

**Problem**: Cannot fetch Confluence page for meeting notes or specs

**Solutions:**
1. Verify the page URL is correct
2. Check if you have view permissions for the space
3. Ensure the page ID in the URL is valid

### Rate Limiting

**Problem**: "Rate limit exceeded" errors

**Solutions:**
1. Wait a few minutes before making more requests
2. Reduce the frequency of API calls
3. Jira Cloud has API limits that reset periodically

## Development

### Project Structure

```text
plugins/jira/
├── .claude-plugin/
│   └── plugin.json          # Plugin metadata
├── .mcp.json                 # MCP server registration
├── skills/
│   ├── triage-issue/
│   │   └── SKILL.md          # Bug triage skill
│   ├── capture-tasks-from-meeting-notes/
│   │   └── SKILL.md          # Meeting task extraction
│   ├── generate-status-report/
│   │   └── SKILL.md          # Status report generation
│   ├── search-company-knowledge/
│   │   └── SKILL.md          # Knowledge search
│   └── spec-to-backlog/
│       └── SKILL.md          # Spec to backlog conversion
├── package.json
└── README.md
```

### Testing

```bash
cd plugins/jira
bun test
# or
bats tests/
```

## License

MIT
