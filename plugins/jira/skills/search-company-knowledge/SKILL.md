---
name: search-company-knowledge
description: "Search Jira to find and explain internal concepts, processes, and technical details through issues and comments. When Claude needs to: (1) Find or search for information about systems, terminology, processes, deployment, authentication, infrastructure, architecture, or technical concepts, (2) Search issue history, comments, or work logs, (3) Explain what something is, how it works, or look up information, or (4) Synthesize information from multiple Jira sources. Searches in parallel and provides cited answers."
---

# Search Company Knowledge

## Keywords
find information, search jira, look up, what is, explain, issue search, jira search, our documentation, internal knowledge, knowledge base, search for, tell me about, get information about, company systems, terminology, find everything about, what do we know about, deployment, authentication, infrastructure, processes, procedures, how to, how does, our systems, our processes, internal systems, company processes, technical documentation, search issues, find in jira

## Overview

Search Jira issues, comments, and history to find comprehensive answers to questions about internal concepts, systems, and terminology. This skill performs targeted searches across Jira and synthesizes results with proper citations.

**Use this skill when:** Users ask about internal company knowledge that might be documented in Jira tickets, comments, or work logs.

---

## Workflow

Follow this 5-step process to provide comprehensive, well-cited answers:

### Step 1: Identify Search Query

Extract the core search terms from the user's question.

**Examples:**
- User: "Find everything about Stratus minions" -> Search: "Stratus minions"
- User: "What do we know about the billing system?" -> Search: "billing system"
- User: "Explain our deployment process" -> Search: "deployment process"

**Consider:**
- Main topic or concept
- Any specific system/component names
- Technical terms or jargon

---

### Step 2: Execute Search

Search Jira for relevant information.

#### Primary Search Method

Use **`searchJiraIssuesUsingJql`** to search Jira issues:

```
searchJiraIssuesUsingJql(
  cloudId="...",
  jql="text ~ 'search terms' OR summary ~ 'search terms'"
)
```

**When to use:**
- Default approach for most queries
- Looking for historical problems or implementation details
- Need to understand past decisions or changes

**Example JQL patterns:**
```
text ~ "Stratus minions"
summary ~ "authentication" AND type = Bug
text ~ "deployment" AND created >= -90d
```

#### Search Strategy

**For most queries, use this sequence:**

1. Start with broad text search
2. If results are unclear, try different search terms
3. If results mention specific tickets, fetch them for details

---

### Step 3: Fetch Detailed Content

After identifying relevant sources, fetch full content for comprehensive answers.

#### For Jira Issues

When search results reference Jira issues:

```
getJiraIssue(
  cloudId="...",
  issueIdOrKey="PROJ-123"
)
```

**Returns:** Full issue details including description, comments, status

**When to fetch:**
- Need to understand a reported bug or issue
- Search result doesn't show full context
- Issue contains important implementation notes

#### Prioritization

**Fetch in this order:**
1. **Recent/relevant issues** (tickets that are relevant and recent)
2. **Related issues** (issues linked to initial results)
3. **Historical context** (older issues that provide background)

**Don't fetch everything** - be selective based on relevance to user's question.

---

### Step 4: Synthesize Results

Combine information from multiple sources into a coherent answer.

#### Synthesis Guidelines

**Structure your answer:**

1. **Direct Answer First**
   - Start with a clear, concise answer to the question
   - "Stratus minions are..."

2. **Detailed Explanation**
   - Provide comprehensive details from all sources
   - Organize by topic, not by source

3. **Source Attribution**
   - Note where each piece of information comes from
   - Format: "According to [source], ..."

4. **Highlight Discrepancies**
   - If sources conflict, note it explicitly
   - Example: "Issue PROJ-123 indicates that due to bug Y, the behavior is actually Z"

5. **Provide Context**
   - Mention if information is outdated
   - Note if a feature is deprecated or in development

#### Synthesis Patterns

**Pattern 1: Multiple sources agree**
```
Stratus minions are background worker processes that handle async tasks.

According to several Jira tickets (PROJ-145, PROJ-203) which discuss
minion configuration and scaling strategies.
```

**Pattern 2: Sources provide different aspects**
```
The billing system has two main components:

**Payment Processing** (from PROJ-189)
- Handles credit card transactions
- Integrates with Stripe API
- Runs nightly reconciliation

**Invoice Generation** (from PROJ-200)
- Creates monthly invoices
- Note: Currently has a bug where tax calculation fails for EU customers
- Fix planned for Q1
```

**Pattern 3: Conflicting information**
```
There is conflicting information about the authentication timeout:

- **Official Decision** (PROJ-456, Oct 2023): 30-minute session timeout
- **Implementation Reality** (PROJ-789, filed Dec 2023): Actual timeout is
  15 minutes due to load balancer configuration
- **Status:** Engineering team aware, fix planned but no timeline yet

Current behavior: Expect 15-minute timeout.
```

**Pattern 4: Incomplete information**
```
Based on available Jira issues:

[What we know about deployment process from issues]

However, I couldn't find information about:
- Rollback procedures
- Database migration handling

You may want to check with the DevOps team or search for additional documentation.
```

---

### Step 5: Provide Citations

Always include links to source materials so users can explore further.

#### Citation Format

**For Jira issues:**
```
**Related Tickets:**
- [PROJ-123](https://yoursite.atlassian.net/browse/PROJ-123) - Brief description
- [PROJ-456](https://yoursite.atlassian.net/browse/PROJ-456) - Brief description
```

**Complete citation section:**
```
## Sources

**Jira Issues:**
- [PROJ-145](https://yoursite.atlassian.net/browse/PROJ-145) - Minion scaling implementation
- [PROJ-203](https://yoursite.atlassian.net/browse/PROJ-203) - Performance optimization
```

---

## Search Best Practices

### Effective Search Terms

**Do:**
- Use specific technical terms: "OAuth authentication flow"
- Include system names: "Stratus minions"
- Use acronyms if they're common: "API rate limiting"
- Try variations if first search fails: "deploy process" -> "deployment pipeline"

**Don't:**
- Be too generic: "how things work"
- Use full sentences: Use key terms instead
- Include filler words: "the", "our", "about"

### Search Result Quality

**Good results:**
- Recent issues (< 1 year old)
- Multiple sources confirming same information
- Detailed implementation notes

**Questionable results:**
- Very old tickets (> 2 years, may be outdated)
- Duplicate or conflicting information
- Draft or work-in-progress issues

**When results are poor:**
- Try different search terms
- Expand search to include related concepts
- Search for specific error messages or codes
- Ask user for more context

---

## Handling Common Scenarios

### Scenario 1: No Results Found

If searches return no results:

```
I searched Jira but couldn't find information about "[topic]".

This could mean:
- The concept hasn't been documented in Jira yet
- It might be called something else (can you provide alternative names?)
- Documentation might be in a different system

Would you like me to:
1. Try searching with different terms?
2. Search for related concepts?
3. Look for mentions in recent Jira tickets?
```

### Scenario 2: Too Many Results

If search returns 50+ results:

- Focus on most recent and most relevant (top 10-15)
- Prioritize issues with detailed descriptions
- Group similar results: "I found 15 tickets related to authentication bugs..."
- Offer to narrow search: "Would you like me to focus on [specific aspect]?"

### Scenario 3: Ambiguous Query

If the user's question is vague:

```
I found information about several topics related to "[term]":
1. [Topic A] - from PROJ-123
2. [Topic B] - from PROJ-456
3. [Topic C] - from PROJ-789

Which aspect are you most interested in?
```

### Scenario 4: Outdated Information

If you find information is old:

```
I found information about [topic], but note that it's from [date] and may be outdated.

[Provide the information anyway]

You may want to verify this is still current, especially if it's from more than
a year ago.
```

---

## Examples

### Example 1: Clear Documentation Available

**User:** "What are Stratus minions?"

**Process:**
1. Search: `searchJiraIssuesUsingJql(cloudId="...", jql='text ~ "Stratus minions"')`
2. Find: 3 Jira tickets about minions
3. Fetch: Get full issue details
4. Synthesize: Combine architectural overview with implementation details
5. Cite: Provide links to all sources

**Answer:**
```
Stratus minions are background worker processes that handle asynchronous task
processing in the Stratus system.

**Key Characteristics:**
- Run independently from web servers
- Process jobs from a Redis queue
- Can be scaled horizontally for increased throughput
- Handle tasks like email sending, report generation, and data processing

**Architecture:**
According to PROJ-145, minions follow a worker-queue pattern where:
1. Web application enqueues tasks
2. Minions poll the queue for work
3. Tasks are processed asynchronously
4. Results are stored in the database

**Implementation Notes:**
From PROJ-203, the current deployment runs 5 minion instances,
with plans to scale to 10 for handling increased load.

## Sources
- [PROJ-145](https://yoursite.atlassian.net/browse/PROJ-145) - Minion architecture design
- [PROJ-203](https://yoursite.atlassian.net/browse/PROJ-203) - Minion scaling implementation
```

### Example 2: Conflicting Information

**User:** "How long is our session timeout?"

**Process:**
1. Search Jira for session timeout information
2. Find: Docs say 30 min, but ticket reports actual timeout is 15 min
3. Fetch both sources for complete context
4. Clearly note the discrepancy

**Answer:**
```
There is a discrepancy between documented and actual behavior:

**Official Decision** (PROJ-456):
Session timeout is configured for 30 minutes of inactivity.

**Actual Behavior** (PROJ-789, reported Dec 2023):
Users are being logged out after 15 minutes due to a load balancer configuration
that overrides the application setting.

**Current Status:**
The engineering team is aware of this issue. The load balancer timeout needs to
be adjusted to match the application setting. No fix timeline has been set.

**Recommendation:** Plan for 15-minute timeout until this is resolved.

## Sources
- [PROJ-456](https://yoursite.atlassian.net/browse/PROJ-456) - Original timeout decision
- [PROJ-789](https://yoursite.atlassian.net/browse/PROJ-789) - Timeout discrepancy bug report
```

### Example 3: Partial Information

**User:** "Explain our deployment process"

**Process:**
1. Search finds some information but not complete
2. Synthesize what is available
3. Note gaps in documentation

**Answer:**
```
Based on available Jira issues, here's what I found about the deployment process:

**Build Phase** (from PROJ-789):
1. Code pushed to main branch triggers CI pipeline
2. Automated tests run (unit, integration)
3. Docker image built and pushed to registry

**Deployment Phase** (from PROJ-790):
4. Staging deployment happens automatically
5. Manual approval required for production
6. Blue-green deployment strategy used

**Gaps in Documentation:**
I couldn't find documented information about:
- Rollback procedures
- Database migration handling
- Post-deployment verification steps

These details may exist in tribal knowledge or need to be documented.

## Sources
- [PROJ-789](https://yoursite.atlassian.net/browse/PROJ-789) - CI/CD pipeline setup
- [PROJ-790](https://yoursite.atlassian.net/browse/PROJ-790) - Deployment pipeline implementation

Would you like me to search for more specific aspects of deployment?
```

---

## Tips for High-Quality Answers

### Do:
- Always search before answering (don't rely on general knowledge)
- Cite all sources with links
- Note discrepancies explicitly
- Mention when information is old
- Provide context and examples
- Structure answers clearly with headers
- Link to related issues

### Don't:
- Assume general knowledge applies to this company
- Make up information if search returns nothing
- Ignore conflicting information
- Quote entire issues (summarize instead)
- Overwhelm with too many sources (curate top 5-10)
- Forget to fetch details when snippets are insufficient

---

## When NOT to Use This Skill

This skill is for **Jira-based knowledge search only**. Do NOT use for:

- General technology questions (use your training knowledge)
- External documentation (use web_search)
- Company-agnostic questions
- Questions about other companies
- Current events or news

**Examples of what NOT to use this skill for:**
- "What is machine learning?" (general knowledge)
- "How does React work?" (external documentation)
- "What's the weather?" (not knowledge search)
- "Find a restaurant" (not work-related)

---

## Quick Reference

**Primary tool:** `searchJiraIssuesUsingJql(cloudId, jql)` - Search Jira issues

**Follow-up tools:**
- `getJiraIssue(cloudId, issueIdOrKey)` - Get full issue details

**Answer structure:**
1. Direct answer
2. Detailed explanation
3. Source attribution
4. Discrepancies (if any)
5. Citations with links

**Remember:**
- Search before answering
- Synthesize, don't just list
- Always cite sources
- Note conflicts explicitly
- Be clear about gaps in documentation
