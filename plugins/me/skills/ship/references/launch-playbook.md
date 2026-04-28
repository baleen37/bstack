# Launch Playbook

Source content for `/ship` tasks. Read sections at EXECUTE phase. Adapted from [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) `shipping-and-launch` (MIT).

Do not summarize this playbook inline in `/ship` output. Point the user to the relevant section by name.

## Pre-launch checklist

### Code quality
- All tests pass (unit, integration, e2e)
- Build succeeds with no warnings
- Lint and type checking pass
- Code reviewed and approved
- No TODO comments that should be resolved before launch
- No `console.log` debugging statements in production code
- Error handling covers expected failure modes

### Security
- No secrets in code or version control
- `npm audit` shows no critical or high vulnerabilities
- Input validation on all user-facing endpoints
- Authentication and authorization checks in place
- Security headers configured (CSP, HSTS, etc.)
- Rate limiting on authentication endpoints
- CORS configured to specific origins (not wildcard)

### Performance
- Core Web Vitals within "Good" thresholds
- No N+1 queries in critical paths
- Images optimized (compression, responsive sizes, lazy loading)
- Bundle size within budget
- Database queries have appropriate indexes
- Caching configured for static assets and repeated queries

### Accessibility
- Keyboard navigation works for all interactive elements
- Screen reader can convey page content and structure
- Color contrast meets WCAG 2.1 AA (4.5:1 for text)
- Focus management correct for modals and dynamic content
- Error messages are descriptive and associated with form fields
- No accessibility warnings in axe-core or Lighthouse

### Infrastructure
- Environment variables set in production
- Database migrations applied (or ready to apply)
- DNS and SSL configured
- CDN configured for static assets
- Logging and error reporting configured
- Health check endpoint exists and responds

### Documentation
- README updated with any new setup requirements
- API documentation current
- ADRs written for any architectural decisions
- Changelog updated
- User-facing documentation updated (if applicable)

## Feature flag lifecycle

```
1. DEPLOY with flag OFF     → Code in production but inactive
2. ENABLE for team/beta     → Internal testing in production
3. GRADUAL ROLLOUT          → 5% → 25% → 50% → 100%
4. MONITOR at each stage    → Error rates, performance, feedback
5. CLEAN UP                 → Remove flag and dead path after rollout
```

Rules:
- Every flag has an owner and an expiration date
- Clean up flags within 2 weeks of full rollout
- Don't nest feature flags
- Test both flag states (on and off) in CI

## Staged rollout sequence

```
1. DEPLOY to staging
   └── Full test suite + manual smoke test of critical flows

2. DEPLOY to production (flag OFF)
   └── Health check + verify no new errors

3. ENABLE for team (flag ON for internal users)
   └── 24-hour monitoring window

4. CANARY (flag ON for 5% of users)
   └── 24-48 hour monitoring window
   └── Advance only if all thresholds pass

5. GRADUAL increase (25% → 50% → 100%)
   └── Same monitoring at each step

6. FULL rollout (flag ON for all users)
   └── Monitor for 1 week
   └── Clean up feature flag
```

## Rollout decision thresholds

| Metric | Advance | Hold and investigate | Roll back |
|---|---|---|---|
| Error rate | Within 10% of baseline | 10–100% above baseline | >2x baseline |
| P95 latency | Within 20% of baseline | 20–50% above baseline | >50% above baseline |
| Client JS errors | No new error types | New errors at <0.1% sessions | New errors at >0.1% sessions |
| Business metrics | Neutral or positive | Decline <5% (may be noise) | Decline >5% |

## Roll back immediately if

- Error rate increases by more than 2x baseline
- P95 latency increases by more than 50%
- User-reported issues spike
- Data integrity issues detected
- Security vulnerability discovered

## What to monitor

```
Application:
├── Error rate (total and by endpoint)
├── Response time (p50, p95, p99)
├── Request volume
├── Active users
└── Key business metrics

Infrastructure:
├── CPU and memory
├── DB connection pool
├── Disk space
├── Network latency
└── Queue depth

Client:
├── Core Web Vitals (LCP, INP, CLS)
├── JS errors
├── API error rates from client
└── Page load time
```

## Post-launch verification (first hour)

1. Health endpoint returns 200
2. Error monitoring shows no new error types
3. Latency dashboard shows no regression
4. Critical user flow works end-to-end
5. Logs are flowing and readable
6. Rollback mechanism verified ready

## Rollback plan template

```markdown
## Rollback Plan for [Feature/Release]

### Trigger conditions
- Error rate > 2x baseline
- P95 latency > [X]ms
- User reports of [specific issue]

### Rollback steps
1. Disable feature flag (if applicable)
   OR
1. Deploy previous version: `git revert <commit> && git push`
2. Verify rollback: health check, error monitoring
3. Communicate: notify team

### Database considerations
- Migration [X] has a rollback: `<command>`
- Data inserted by new feature: [preserved / cleaned up]

### Time to rollback
- Feature flag: < 1 minute
- Redeploy previous version: < 5 minutes
- Database rollback: < 15 minutes
```
