# Create-PR Skill Quality Checklist

## RED Phase - Write Failing Test ✅

- [x] Create pressure scenarios (3+ combined pressures for discipline skills)
  - Scenario 1: Conflict detection failure
  - Scenario 2: Auto-merge option not considered
  - Scenario 3: Working directly on main
  - Stress test: Combined pressures (time + sunk cost + authority + exhaustion)

- [x] Run scenarios WITHOUT skill - document baseline behavior verbatim
  - All scenarios executed with general-purpose agent
  - Rationalizations captured verbatim

- [x] Identify patterns in rationalizations/failures
  - "시간 압박으로 건너뜀"
  - "사후 발견/대응"
  - "놓칠 수 있는 부분"으로 면죄부
  - "Repo 설정 확인 생략"

## GREEN Phase - Write Minimal Skill ✅

- [x] Name uses only letters, numbers, hyphens (no parentheses/special chars)
  - ✅ `create-pr`

- [x] YAML frontmatter with only name and description (max 1024 chars)
  - ✅ 2 fields only
  - ✅ 172 characters (well under 1024)

- [x] Description starts with "Use when..." and includes specific triggers/symptoms
  - ✅ "Use when user requests 'create PR', 'make pull request'..."
  - ✅ Includes triggering conditions

- [x] Description written in third person
  - ✅ No first person

- [x] Keywords throughout for search (errors, symptoms, tools)
  - ✅ "conflict", "auto-merge", "git push", "gh pr create"
  - ✅ "main/master", "rebase", "branch protection"

- [x] Clear overview with core principle
  - ✅ Line 10-12: "Commit → Push → PR workflow with mandatory safety checks"
  - ✅ Time pressure principle stated upfront

- [x] Address specific baseline failures identified in RED
  - ✅ Conflict detection: Pre-Flight Checks (Line 14-35)
  - ✅ Auto-merge: Workflow step 4 + Auto-merge Requirements (Line 53-70)
  - ✅ Main branch: Pre-Flight check 1 (Line 17-19)

- [x] Code inline OR link to separate file
  - ✅ All code inline (bash blocks)

- [x] One excellent example (not multi-language)
  - ✅ Bash/shell examples only
  - ✅ Complete, runnable commands

- [x] Run scenarios WITH skill - verify agents now comply
  - ✅ Scenario 1: Agent correctly detects conflicts in pre-flight
  - ✅ Scenario 2: Agent checks auto-merge requirements and enables it
  - ✅ Stress test: Agent resists all pressure tactics

## REFACTOR Phase - Close Loopholes ✅

- [x] Identify NEW rationalizations from testing
  - ✅ "Rebase 후 테스트 스킵해도 될 것" (discovered in stress test)

- [x] Add explicit counters (if discipline skill)
  - ✅ Conflict Resolution: Added MANDATORY test requirement (Line 81-83)
  - ✅ Rationalizations Table: Added "Rebase 후 테스트 스킵" + "프로덕션 긴급" (Line 102-103)
  - ✅ Red Flags: Added "Skipping tests after conflict resolution" (Line 112)

- [x] Build rationalization table from all test iterations
  - ✅ 6 rationalizations covered (Line 96-103)
  - ✅ Each with Reality counter

- [x] Create red flags list
  - ✅ 7 red flags (Line 107-113)
  - ✅ Clear action: "Any of these = STOP"

- [x] Re-test until bulletproof
  - ✅ Stress test re-run with improved skill
  - ✅ Agent correctly applies MANDATORY test step

## Quality Checks ✅

- [x] Small flowchart only if decision non-obvious
  - ✅ No flowchart needed - workflow is linear with clear branches

- [x] Quick reference table
  - ✅ Rationalizations Table (Line 94-103)
  - ✅ Auto-merge Requirements (Line 57-70)

- [x] Common mistakes section
  - ✅ Rationalizations Table serves this purpose
  - ✅ Red Flags section (Line 105-115)

- [x] No narrative storytelling
  - ✅ All content is procedural/reference

- [x] Supporting files only for tools or heavy reference
  - ✅ test-scenarios.md for testing (not part of skill delivery)
  - ✅ SKILL.md is self-contained

## Additional Quality Metrics

### Token Efficiency
```bash
wc -w skills/create-pr/SKILL.md
```
Expected: <500 words (this is a frequently-used skill)

- ✅ 336 words (well under 500)

### CSO (Claude Search Optimization)

- [x] Description focuses on WHEN not WHAT
  - ✅ "Use when user requests..." (triggering condition)
  - ✅ No workflow summary in description

- [x] Keywords for search
  - ✅ "create PR", "pull request", "commit", "push"
  - ✅ Technology-agnostic where appropriate

- [x] Active voice, verb-first naming
  - ✅ `create-pr` (verb-first)

### Structure Check

- [x] Overview section
  - ✅ Core principle (Line 10-12)

- [x] When to Use (implicit in description)
  - ✅ Covered in YAML frontmatter

- [x] Implementation sections
  - ✅ Pre-Flight Checks
  - ✅ Workflow
  - ✅ Auto-merge Requirements
  - ✅ Conflict Resolution
  - ✅ Stop Conditions

- [x] Rationalizations/Red Flags
  - ✅ Both present

## Deployment ✅

- [ ] Commit skill to git and push to fork
- [ ] Consider contributing back via PR (if broadly useful)

## Final Assessment

**Status**: READY FOR DEPLOYMENT

**Key Strengths**:
1. TDD methodology fully applied (RED → GREEN → REFACTOR)
2. Comprehensive testing with pressure scenarios
3. Strong rationalization counters
4. Self-contained and concise (336 words)
5. Clear CSO optimization

**Unique Features**:
1. "Pressure Is NOT Justification" section - psychological defense
2. Three-layer defense (procedural + psychological + principled)
3. MANDATORY keywords for critical steps
4. Combined pressure resistance (stress tested)
