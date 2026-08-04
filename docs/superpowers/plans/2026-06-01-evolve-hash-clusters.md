# Evolve Observed Bodies Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `/me:evolve --recent` and `--skill` analyze only sessions whose injected SKILL.md body matches the current SKILL.md body, while showing simple hash/version diagnostics for excluded sessions.

**Architecture:** Keep the current recent-index shape. Add one diagnostic `observed_bodies` array per skill; top-level `events` remain the only proposal evidence and are filtered to the current body hash. `versions` are diagnostic only; freshness is decided only by normalized body hash.

**Tech Stack:** Bun TypeScript script (`build-index.ts`), BATS tests, jq assertions, Markdown SKILL.md docs.

---

## File Structure

- Modify `plugins/me/skills/evolve/scripts/build-index.ts`
  - Add `hash` and `version` to each skill invocation.
  - Group recent-mode observations by normalized SKILL.md body hash.
  - Emit `observed_bodies` diagnostics.
  - Keep top-level `events` filtered to the current body hash only.
- Modify `plugins/me/skills/evolve/SKILL.md`
  - State that top-level `events` are the only valid evidence.
  - State that `observed_bodies` is diagnostic only.
- Modify `tests/me/evolve-build-index.bats`
  - Add minimal tests for same-body/different-version, different-body exclusion, and current-body-with-no-events.

---

### Task 1: Add invocation hash/version metadata

**Files:**
- Modify: `plugins/me/skills/evolve/scripts/build-index.ts:51-60`
- Modify: `plugins/me/skills/evolve/scripts/build-index.ts:86-90`
- Modify: `plugins/me/skills/evolve/scripts/build-index.ts:122-129`
- Modify: `plugins/me/skills/evolve/scripts/build-index.ts:165-188`

- [ ] **Step 1: Add output and invocation types**

In `plugins/me/skills/evolve/scripts/build-index.ts`, add this type before `RecentSkill`:

```ts
interface ObservedBody {
  hash: string;
  current: boolean;
  versions: string[];
  seen_in: string[];
  signal: string;
}
```

Update `RecentSkill` to include:

```ts
  current_hash?: string;  // 현재 normalized SKILL.md 본문 hash (짧은 prefix)
  observed_bodies: ObservedBody[]; // 진단용: 관측된 본문 hash/version/session 요약
```

Update `SkillInvocation` to be:

```ts
interface SkillInvocation {
  name: string;     // skill 식별자 (Base directory의 마지막 디렉터리명)
  baseDir: string;  // 주입 본문의 Base directory 절대경로
  version: string;  // cache path에서 관측된 version, 없으면 "unknown"
  hash: string;     // normalized injected body hash
}
```

- [ ] **Step 2: Add small helpers**

After `bodyHash()`, add:

```ts
function shortHash(hash: string): string {
  return hash.slice(0, 8);
}

function skillVersion(baseDir: string): string {
  const parts = baseDir.split(/[\\/]+/);
  const skillsIdx = parts.lastIndexOf("skills");
  if (skillsIdx < 1) return "unknown";
  return parts[skillsIdx - 1] || "unknown";
}
```

- [ ] **Step 3: Store hash/version when loading skill injections**

Replace the `skillInvocations.push(...)` block in `loadTurns()` with:

```ts
const injectedBody = stripBaseDirLine(text);
skillInvocations.push({
  name: basename(baseDir),
  baseDir,
  version: skillVersion(baseDir),
  hash: bodyHash(injectedBody),
});
```

- [ ] **Step 4: Run the existing stale tests before the grouping change**

Run:

```bash
bats tests/me/evolve-build-index.bats --filter "stale"
```

Expected: PASS or unchanged existing behavior. If this fails before Task 2, fix only type/compile mistakes from this task.

---

### Task 2: Filter top-level events by current body hash

**Files:**
- Modify: `plugins/me/skills/evolve/scripts/build-index.ts:440-527`

- [ ] **Step 1: Replace the recent accumulator shape**

In `buildRecentIndex()`, replace the `acc` map value type with:

```ts
  const acc = new Map<string, {
    baseDir: string;
    versionsByHash: Map<string, Set<string>>;
    seenByHash: Map<string, Set<string>>;
    seen: Set<string>;
    eventsByHash: Map<string, Event[]>;
  }>();
```

- [ ] **Step 2: Record hashes observed in each session**

Inside the `for (const p of paths)` loop, replace the current skill invocation accumulation with:

```ts
    const invokedHashesByName = new Map<string, Set<string>>();
    for (const inv of skillInvocations) {
      invokedNames.add(inv.name);
      if (!invokedHashesByName.has(inv.name)) invokedHashesByName.set(inv.name, new Set());
      invokedHashesByName.get(inv.name)!.add(inv.hash);

      if (!acc.has(inv.name)) {
        acc.set(inv.name, {
          baseDir: inv.baseDir,
          versionsByHash: new Map(),
          seenByHash: new Map(),
          seen: new Set(),
          eventsByHash: new Map(),
        });
      }

      const a = acc.get(inv.name)!;
      a.baseDir = inv.baseDir;
      a.seen.add(sessionId);
      if (!a.versionsByHash.has(inv.hash)) a.versionsByHash.set(inv.hash, new Set());
      a.versionsByHash.get(inv.hash)!.add(inv.version);
      if (!a.seenByHash.has(inv.hash)) a.seenByHash.set(inv.hash, new Set());
      a.seenByHash.get(inv.hash)!.add(sessionId);
      if (!a.eventsByHash.has(inv.hash)) a.eventsByHash.set(inv.hash, []);
    }
```

- [ ] **Step 3: Attribute events to observed body hashes**

Replace the existing event attribution block with:

```ts
    for (const ev of events) {
      const tagged: Event = { ...ev, session: sessionId };
      if (ev.kind === "skill" && ev.name) {
        const short = ev.name.includes(":") ? ev.name.split(":").pop()! : ev.name;
        const hashes = invokedHashesByName.get(short) ?? new Set<string>();
        for (const hash of hashes) acc.get(short)?.eventsByHash.get(hash)?.push(tagged);
      } else {
        for (const [name, hashes] of invokedHashesByName) {
          const a = acc.get(name)!;
          for (const hash of hashes) a.eventsByHash.get(hash)?.push(tagged);
        }
      }
    }
```

Keep this session-level attribution simple. Do not add turn-range attribution in this change.

- [ ] **Step 4: Emit only current-body events at the top level**

Replace the `for (const [name, a] of acc)` body from `const cacheSkillMd...` through `skills.push(...)` with:

```ts
    const cacheSkillMd = join(a.baseDir, "SKILL.md");
    const repoPath = repoSkillPath(repoRoot, name);
    const nowHashFull = currentBodyHash(repoPath ?? cacheSkillMd);
    const hasCurrentBody = nowHashFull !== null && a.versionsByHash.has(nowHashFull);
    const matchingEvents = hasCurrentBody ? (a.eventsByHash.get(nowHashFull) ?? []) : [];
    const stale = !hasCurrentBody;
    const dropped = stale;
    const evs = dropped ? [] : matchingEvents;
    const { signal, weight } = summarizeSignal(evs);
    const observedBodies: ObservedBody[] = [...a.versionsByHash.keys()].sort().map((hash) => {
      const bodyEvents = a.eventsByHash.get(hash) ?? [];
      return {
        hash: shortHash(hash),
        current: hash === nowHashFull,
        versions: [...(a.versionsByHash.get(hash) ?? new Set())].sort(),
        seen_in: [...(a.seenByHash.get(hash) ?? new Set())].sort(),
        signal: summarizeSignal(bodyEvents).signal,
      };
    });

    skills.push({
      name,
      skill_path: cacheSkillMd,
      ...(repoPath ? { repo_path: repoPath } : {}),
      ...(nowHashFull ? { current_hash: shortHash(nowHashFull) } : {}),
      stale,
      dropped,
      seen_in: [...a.seen].sort(),
      signal: dropped ? "dropped (stale)" : signal,
      observed_bodies: observedBodies,
      events: evs,
      _weight: weight,
    });
```

Important: `stale` depends on whether the current hash was observed, not whether current-hash events are non-empty.

---

### Task 3: Add focused tests

**Files:**
- Modify: `tests/me/evolve-build-index.bats`

- [ ] **Step 1: Add a test for same body across versions**

Append near the existing stale tests:

```bash
@test "evolve build-index: observed_bodies show versions and keep current-body events only" {
    local repo="$BATS_TEST_TMPDIR/obsrepo"
    mkdir -p "$repo/plugins/me/skills/observed"
    printf -- '# observed body\n\nsame.\n' > "$repo/plugins/me/skills/observed/SKILL.md"
    cd "$repo"
    local real_repo; real_repo="$(pwd -P)"
    local pdir="$HOME/.claude/projects/$(echo "$real_repo" | sed 's#[/.]#-#g')"
    mkdir -p "$pdir"

    local current_v1; current_v1="$(printf 'Base directory for this skill: %s\n\n# observed body\n\nsame.\n' "$BATS_TEST_TMPDIR/cache/bstack/bstack/17.18.0/skills/observed")"
    local current_v2; current_v2="$(printf 'Base directory for this skill: %s\n\n# observed body\n\nsame.\n' "$BATS_TEST_TMPDIR/cache/bstack/bstack/17.19.1/skills/observed")"
    local old_body; old_body="$(printf 'Base directory for this skill: %s\n\n# observed body\n\nold.\n' "$BATS_TEST_TMPDIR/cache/bstack/bstack/17.17.0/skills/observed")"

    jq -c '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"o1","name":"Skill","input":{"skill":"observed"}}]}}' -n > "$pdir/a.jsonl"
    jq -c --arg t "$current_v1" '{"type":"user","isMeta":true,"sourceToolUseID":"o1","message":{"role":"user","content":[{"type":"text","text":$t}]}}' -n >> "$pdir/a.jsonl"
    jq -c '{"type":"user","message":{"role":"user","content":[{"type":"text","text":"current user signal"}]}}' -n >> "$pdir/a.jsonl"

    jq -c '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"o2","name":"Skill","input":{"skill":"observed"}}]}}' -n > "$pdir/b.jsonl"
    jq -c --arg t "$current_v2" '{"type":"user","isMeta":true,"sourceToolUseID":"o2","message":{"role":"user","content":[{"type":"text","text":$t}]}}' -n >> "$pdir/b.jsonl"

    jq -c '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"o3","name":"Skill","input":{"skill":"observed"}}]}}' -n > "$pdir/c.jsonl"
    jq -c --arg t "$old_body" '{"type":"user","isMeta":true,"sourceToolUseID":"o3","message":{"role":"user","content":[{"type":"text","text":$t}]}}' -n >> "$pdir/c.jsonl"
    jq -c '{"type":"user","message":{"role":"user","content":[{"type":"text","text":"old user signal"}]}}' -n >> "$pdir/c.jsonl"

    run bun "$INDEXER" --recent 10
    rm -rf "$pdir"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '[.skills[] | select(.name == "observed")][0].dropped == false'
    echo "$output" | jq -e '[.skills[] | select(.name == "observed")][0].observed_bodies | length == 2'
    echo "$output" | jq -e '[.skills[] | select(.name == "observed")][0].observed_bodies[] | select(.current == true) | .versions == ["17.18.0","17.19.1"]'
    echo "$output" | jq -e '[.skills[] | select(.name == "observed")][0].observed_bodies[] | select(.current == false) | .versions == ["17.17.0"]'
    echo "$output" | jq -e '[.skills[] | select(.name == "observed")][0].events | map(select(.text == "old user signal")) | length == 0'
}
```

- [ ] **Step 2: Add a test for current body with no signal events**

Append:

```bash
@test "evolve build-index: current body with no events is not stale" {
    local skilldir="$BATS_TEST_TMPDIR/skills/noevents"
    mkdir -p "$skilldir"
    printf -- '# noevents body\n' > "$skilldir/SKILL.md"

    local proj="$BATS_TEST_TMPDIR/noeventsproj"
    mkdir -p "$proj"
    cd "$proj"
    local real_proj; real_proj="$(pwd -P)"
    local real_skilldir; real_skilldir="$(cd "$skilldir" && pwd -P)"
    local pdir="$HOME/.claude/projects/$(echo "$real_proj" | sed 's#[/.]#-#g')"
    mkdir -p "$pdir"
    local text; text="$(printf 'Base directory for this skill: %s\n\n# noevents body\n' "$real_skilldir")"
    jq -c '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"n1","name":"Skill","input":{"skill":"noevents"}}]}}' -n > "$pdir/s.jsonl"
    jq -c --arg t "$text" '{"type":"user","isMeta":true,"sourceToolUseID":"n1","message":{"role":"user","content":[{"type":"text","text":$t}]}}' -n >> "$pdir/s.jsonl"

    run bun "$INDEXER" --recent 3
    rm -rf "$pdir"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '[.skills[] | select(.name == "noevents")][0].stale == false'
    echo "$output" | jq -e '[.skills[] | select(.name == "noevents")][0].events | length == 0'
}
```

- [ ] **Step 3: Run the two new tests and verify they fail before implementation**

Run:

```bash
bats tests/me/evolve-build-index.bats --filter "observed_bodies show versions|current body with no events"
```

Expected: FAIL before Task 2 is implemented; PASS after Task 2.

---

### Task 4: Update SKILL.md with the simple rule

**Files:**
- Modify: `plugins/me/skills/evolve/SKILL.md:66-70`
- Modify: `plugins/me/skills/evolve/SKILL.md:92-95`

- [ ] **Step 1: Replace recent-mode stale explanation**

Use this concise text in the `--recent mode` section:

```markdown
- **Observed bodies**: recent/skill mode groups observations by normalized `SKILL.md` body hash. `versions` are diagnostic only and show where each body hash was observed; freshness is decided only by hash. Top-level `events` include only sessions whose body hash matches the current normalized `SKILL.md` body. `observed_bodies` is diagnostic metadata, not proposal evidence.
```

- [ ] **Step 2: Replace Phase 1 multi-session stale guidance**

Use this concise rule in the Phase 1 multi-session guidance:

```markdown
For multi-session indexes, top-level `events` are the only valid proposal evidence. `observed_bodies` only explains which body hashes and versions were included or excluded. Never use entries with `current:false` as evidence. If `dropped:true`, the skill is not a proposal target.
```

---

### Task 5: Run targeted validation and commit

**Files:**
- Verify: `plugins/me/skills/evolve/scripts/build-index.ts`
- Verify: `plugins/me/skills/evolve/SKILL.md`
- Verify: `tests/me/evolve-build-index.bats`

- [ ] **Step 1: Run targeted evolve tests**

Run:

```bash
bats tests/me/evolve-build-index.bats
```

Expected: PASS.

- [ ] **Step 2: Run markdown lint for the changed skill doc**

Run:

```bash
pre-commit run markdownlint --files plugins/me/skills/evolve/SKILL.md
```

Expected: PASS. If the hook is unavailable, report the exact failure.

- [ ] **Step 3: Check working tree**

Run:

```bash
git status --short
```

Expected: only these files changed:

```text
 M plugins/me/skills/evolve/SKILL.md
 M plugins/me/skills/evolve/scripts/build-index.ts
 M tests/me/evolve-build-index.bats
?? docs/superpowers/plans/2026-06-01-evolve-hash-clusters.md
```

- [ ] **Step 4: Commit**

Run:

```bash
git add plugins/me/skills/evolve/SKILL.md plugins/me/skills/evolve/scripts/build-index.ts tests/me/evolve-build-index.bats docs/superpowers/plans/2026-06-01-evolve-hash-clusters.md
git commit -m "feat(evolve): explain stale sessions with observed bodies"
```

Expected: commit succeeds without bypassing hooks.

---

## Self-Review

- Spec coverage: The plan keeps strict body-hash exclusion, exposes diagnostic versions, and makes top-level `events` the only valid evidence.
- Placeholder scan: No TBD/TODO/fill-in placeholders remain.
- Type consistency: `observed_bodies`, `current`, `versions`, `seen_in`, and `signal` names are consistent across implementation, docs, and tests.
