---
name: orchestrate
description: Execute sequential agent workflows for complex development tasks
argument-hint: <feature|bugfix|refactor|security|custom> <task>
---

# Orchestrate - Sequential Agent Workflows

Execute complex development tasks through sequential agent collaboration with structured handoffs.

## Your Task

You are orchestrating a workflow of specialized agents to complete a complex development task. Follow this process:

### 1. Workflow Selection

Choose the appropriate workflow based on the task type:

**Feature Workflow:**
- Sequence: planner → tdd-guide → code-reviewer → security-reviewer
- Use for: Full feature implementation from design to deployment

**Bugfix Workflow:**
- Sequence: explorer → tdd-guide → code-reviewer
- Use for: Bug investigation and resolution

**Refactor Workflow:**
- Sequence: architect → code-reviewer → tdd-guide
- Use for: Safe code restructuring and improvements

**Security Workflow:**
- Sequence: security-reviewer → code-reviewer → architect
- Use for: Security-focused reviews and hardening

**Custom Workflow:**
- User-specified agent sequence
- Use for: Non-standard task patterns

### 2. Agent Execution Process

For each agent in the workflow:

1. **Invoke Agent**: Use the Task tool with appropriate subagent_type
2. **Collect Output**: Gather agent's findings and decisions
3. **Create Handoff**: Structure output for next agent
4. **Pass Context**: Include previous work in next agent's prompt

### 3. Handoff Document Format

Between agents, maintain this structure:

```markdown
## Context
[Summary of completed work and current state]

## Findings
[Key discoveries, decisions, or insights]

## Files Modified
[List of files touched or created]

## Open Questions
[Unresolved items requiring attention]

## Recommendations
[Suggested next steps for following agent]
```

### 4. Agent-Specific Guidelines

**Planner Agent:**
- Creates implementation roadmap
- Identifies technical dependencies
- Estimates complexity and risks

**Explorer Agent:**
- Investigates codebase for bug causes
- Maps data flows and dependencies
- Identifies root causes

**TDD-Guide Agent:**
- Designs test strategy
- Implements tests before code
- Verifies test coverage

**Code-Reviewer Agent:**
- Reviews code quality and patterns
- Checks for best practices
- Validates implementation correctness

**Security-Reviewer Agent:**
- Identifies security vulnerabilities
- Reviews authentication/authorization
- Checks for PII handling compliance

**Architect Agent:**
- Reviews system design decisions
- Validates architectural patterns
- Ensures scalability considerations

### 5. Final Report Structure

After all agents complete, create a comprehensive report:

```markdown
# Orchestration Report

## Workflow
- Type: [feature/bugfix/refactor/security/custom]
- Task: [original task description]
- Agents: [sequence executed]

## Agent Summaries
[For each agent: key findings and decisions]

## Consolidated Output
[Aggregated results from all agents]

## Modified Files
[Complete list of touched files]

## Test Results
[Test coverage and execution status]

## Security Status
[Security review findings, if applicable]

## Final Recommendation
[SHIP / NEEDS WORK / BLOCKED]

[Detailed rationale for recommendation]
```

### 6. Decision Rules

**When to SHIP:**
- All agents completed successfully
- Tests pass with adequate coverage
- No critical security issues
- Code review approved

**When to mark NEEDS WORK:**
- Minor issues identified
- Additional tests recommended
- Non-critical refactoring suggested

**When to mark BLOCKED:**
- Critical bugs or security issues
- Architectural concerns
- Missing dependencies
- Test failures

### 7. Best Practices

- **Keep Handoffs Focused**: Each handoff should be concise but complete
- **Run Verification**: Execute tests/builds between agents when needed
- **Track Open Questions**: Ensure no items fall through the cracks
- **Aggregate Incrementally**: Build the final report as you go
- **Use Structured Data**: Maintain consistent formatting for easy parsing

### 8. Example Invocations

**Feature Implementation:**
```
/orchestrate feature "Add user authentication with JWT tokens"
```

**Bug Investigation:**
```
/orchestrate bugfix "Memory leak in data processing pipeline"
```

**Code Refactoring:**
```
/orchestrate refactor "Extract payment processing into separate service"
```

**Security Review:**
```
/orchestrate security "Review API authentication and authorization"
```

**Custom Workflow:**
```
/orchestrate custom "explorer,architect,tdd-guide" "Optimize database query performance"
```

## Important Notes

- Always include code-reviewer before considering work complete
- Use security-reviewer for authentication, payments, or PII handling
- Start complex features with planner to establish clear direction
- Custom workflows should still follow logical agent sequencing
- Each agent should build on previous work, not duplicate effort

## Output

Provide the final orchestration report with clear recommendation and comprehensive summary of all agent work.
