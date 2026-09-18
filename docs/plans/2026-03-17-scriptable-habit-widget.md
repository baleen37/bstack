# Scriptable Habit Tracker Widget Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a single Scriptable JavaScript file that renders a Small widget showing last week and this week's habit data as a dot grid, fetched from a Google Apps Script endpoint.

**Architecture:** Single `HabitWidget.js` file with three logical sections: date utilities (pure functions, testable with Node.js), data fetching with cache fallback, and Scriptable widget rendering. Pure logic is extracted so it can be tested outside Scriptable.

**Tech Stack:** JavaScript (ES2020), Scriptable iOS app, Google Apps Script (existing), Node.js (for unit tests only)

---

## Chunk 1: Date Utilities & Value Mapping

### Task 1: Week date range calculator

**Files:**
- Create: `HabitWidget.js` (initial skeleton + date utils)
- Create: `HabitWidget.test.js` (Node.js unit tests — not deployed to Scriptable)

- [ ] **Step 1: Create test file with failing tests for `getWeekDates`**

  `HabitWidget.test.js`:
  ```js
  // Run with: node HabitWidget.test.js
  // No test framework needed — plain assertions

  function assert(condition, message) {
    if (!condition) throw new Error("FAIL: " + message);
    console.log("PASS: " + message);
  }

  // Extract pure functions from HabitWidget.js for testing
  // We'll use a shared module pattern: wrap exportable functions in
  // if (typeof module !== "undefined") module.exports = { ... }

  const { getWeekDates } = require("./HabitWidget.js");

  // Dates are "YYYY-MM-DD" UTC strings (ISO slice), must match API date strings exactly.

  // Today = Wednesday 2026-03-18
  const wednesday = new Date("2026-03-18T12:00:00");
  const { lastWeek, thisWeek } = getWeekDates(wednesday);

  // Last week: Mon 2026-03-09 ~ Sun 2026-03-15
  assert(lastWeek[0] === "2026-03-09", "lastWeek starts on Monday");
  assert(lastWeek[6] === "2026-03-15", "lastWeek ends on Sunday");
  assert(lastWeek.length === 7, "lastWeek has 7 days");

  // This week: Mon 2026-03-16 ~ Sun 2026-03-22
  assert(thisWeek[0] === "2026-03-16", "thisWeek starts on Monday");
  assert(thisWeek[6] === "2026-03-22", "thisWeek ends on Sunday");
  assert(thisWeek.length === 7, "thisWeek has 7 days");

  // Edge: today = Monday
  const monday = new Date("2026-03-16T12:00:00");
  const { lastWeek: lw2, thisWeek: tw2 } = getWeekDates(monday);
  assert(lw2[0] === "2026-03-09", "Monday: lastWeek starts on Mon");
  assert(tw2[0] === "2026-03-16", "Monday: thisWeek starts on today");

  // Edge: today = Sunday 2026-03-15
  const sunday = new Date("2026-03-15T12:00:00");
  const { lastWeek: lw3, thisWeek: tw3 } = getWeekDates(sunday);
  assert(lw3[0] === "2026-03-02", "Sunday: lastWeek starts on prior Mon");
  assert(lw3[6] === "2026-03-08", "Sunday: lastWeek ends on prior Sun");
  assert(tw3[0] === "2026-03-09", "Sunday: thisWeek starts on Mon");
  assert(tw3[6] === "2026-03-15", "Sunday: thisWeek ends on today (Sun)");

  console.log("\nAll date tests passed.");
  ```

- [ ] **Step 2: Run to confirm failure**
  ```bash
  node HabitWidget.test.js
  ```
  Expected: `Error: Cannot find module './HabitWidget.js'`

- [ ] **Step 3: Create `HabitWidget.js` with `getWeekDates`**

  ```js
  // ─── CONFIG ───────────────────────────────────────────────────────────────
  const API_URL = "YOUR_GOOGLE_APPS_SCRIPT_URL_HERE";

  // ─── DATE UTILITIES ───────────────────────────────────────────────────────

  /**
   * Returns { lastWeek: string[], thisWeek: string[] }
   * Each array has 7 date strings "YYYY-MM-DD" Mon→Sun.
   */
  function getWeekDates(today = new Date()) {
    const toStr = (d) => d.toISOString().slice(0, 10);

    // Day of week: 0=Sun,1=Mon,...,6=Sat → normalize to Mon=0
    const dow = (today.getDay() + 6) % 7; // Mon=0, Tue=1, ..., Sun=6

    const thisMonday = new Date(today);
    thisMonday.setDate(today.getDate() - dow);
    thisMonday.setHours(0, 0, 0, 0);

    const lastMonday = new Date(thisMonday);
    lastMonday.setDate(thisMonday.getDate() - 7);

    const range = (start) =>
      Array.from({ length: 7 }, (_, i) => {
        const d = new Date(start);
        d.setDate(start.getDate() + i);
        return toStr(d);
      });

    return { lastWeek: range(lastMonday), thisWeek: range(thisMonday) };
  }

  // ─── MODULE EXPORT (for Node.js testing only) ─────────────────────────────
  if (typeof module !== "undefined") module.exports = { getWeekDates };
  ```

- [ ] **Step 4: Run tests**
  ```bash
  node HabitWidget.test.js
  ```
  Expected: all lines print `PASS:`, final line `All date tests passed.`

- [ ] **Step 5: Commit**
  ```bash
  git add HabitWidget.js HabitWidget.test.js
  git commit -m "feat: add getWeekDates utility with tests"
  ```

---

### Task 2: Value mapping

**Files:**
- Modify: `HabitWidget.js` — add `dotTypeForValue`
- Modify: `HabitWidget.test.js` — add value mapping tests

- [ ] **Step 1: Add failing tests for `dotTypeForValue`**

  Append to `HabitWidget.test.js`:
  ```js
  const { dotTypeForValue } = require("./HabitWidget.js");

  // Returns "filled" | "outline" | "null"
  assert(dotTypeForValue(true)   === "filled",  "true → filled");
  assert(dotTypeForValue(false)  === "outline", "false → outline");
  assert(dotTypeForValue(1)      === "filled",  "positive number → filled");
  assert(dotTypeForValue(5)      === "filled",  "larger number → filled");
  assert(dotTypeForValue(0)      === "outline", "zero → outline");
  assert(dotTypeForValue(-1)     === "outline", "negative number → outline");
  assert(dotTypeForValue(null)   === "null",    "null → null");

  console.log("\nAll value mapping tests passed.");
  ```

- [ ] **Step 2: Run to confirm failure**
  ```bash
  node HabitWidget.test.js
  ```
  Expected: FAIL on `dotTypeForValue`

- [ ] **Step 3: Implement `dotTypeForValue` in `HabitWidget.js`**

  Add after `getWeekDates`:
  ```js
  /** Maps a raw habit value to a dot display type. */
  function dotTypeForValue(value) {
    if (value === null || value === undefined) return "null";
    if (typeof value === "boolean") return value ? "filled" : "outline";
    return value > 0 ? "filled" : "outline";
  }
  ```

  Update module.exports:
  ```js
  if (typeof module !== "undefined") module.exports = { getWeekDates, dotTypeForValue, buildGrid };
  ```

- [ ] **Step 4: Run tests**
  ```bash
  node HabitWidget.test.js
  ```
  Expected: all PASS

- [ ] **Step 5: Commit**
  ```bash
  git add HabitWidget.js HabitWidget.test.js
  git commit -m "feat: add dotTypeForValue with tests"
  ```

---

### Task 3: Data normalizer

**Files:**
- Modify: `HabitWidget.js` — add `buildGrid`
- Modify: `HabitWidget.test.js` — add grid tests

`buildGrid` takes the API response, two week date arrays, and today's date string. Returns a 2D structure: `habitName → { lastWeek: dotType[], thisWeek: dotType[] }`.

Future days (dates after today in `thisWeekDates`) are always treated as null regardless of API data. Habit order follows `habitNames` array exactly.

- [ ] **Step 1: Add failing tests**

  Append to `HabitWidget.test.js`:
  ```js
  const { buildGrid } = require("./HabitWidget.js");

  // today = Wednesday 2026-03-18 → future days this week: Thu~Sun are null
  const todayStr = "2026-03-18";
  const apiResponse = {
    habitNames: ["운동", "독서"],
    Habits: [
      // last week: Mon filled, Tue outline, rest missing
      { date: "2026-03-09", habits: [{ name: "운동", value: true  }, { name: "독서", value: false }] },
      { date: "2026-03-10", habits: [{ name: "운동", value: false }, { name: "독서", value: true  }] },
      // 2026-03-11 ~ 2026-03-15: date entry missing entirely
      // this week: Mon filled (독서 has no entry in habits array), Tue~Sun missing
      { date: "2026-03-16", habits: [{ name: "운동", value: true }] }, // 독서 absent from array
      // 2026-03-17: date missing entirely
      { date: "2026-03-18", habits: [{ name: "운동", value: true  }, { name: "독서", value: true }] },
      // 2026-03-19 ~ 2026-03-22: future, should be null regardless
    ],
  };

  const wed = new Date("2026-03-18T12:00:00");
  const { lastWeek, thisWeek } = getWeekDates(wed);
  const grid = buildGrid(apiResponse, lastWeek, thisWeek, todayStr);

  // last week
  assert(grid["운동"].lastWeek[0] === "filled",  "운동 Mon last week = filled");
  assert(grid["운동"].lastWeek[1] === "outline", "운동 Tue last week = outline");
  assert(grid["운동"].lastWeek[2] === "null",    "운동 Wed last week = null (date missing)");
  assert(grid["독서"].lastWeek[0] === "outline", "독서 Mon last week = outline");
  assert(grid["독서"].lastWeek[1] === "filled",  "독서 Tue last week = filled");

  // this week
  assert(grid["운동"].thisWeek[0] === "filled",  "운동 Mon this week = filled");
  assert(grid["운동"].thisWeek[1] === "null",    "운동 Tue this week = null (date missing)");
  assert(grid["운동"].thisWeek[2] === "filled",  "운동 Wed this week = filled (today)");
  assert(grid["운동"].thisWeek[3] === "null",    "운동 Thu this week = null (future)");
  assert(grid["독서"].thisWeek[0] === "null",    "독서 Mon this week = null (habit absent from array)");
  assert(grid["독서"].thisWeek[2] === "filled",  "독서 Wed this week = filled (today)");

  // habitNames order preserved
  const names = Object.keys(grid);
  assert(names[0] === "운동", "first habit = 운동 (habitNames order)");
  assert(names[1] === "독서", "second habit = 독서 (habitNames order)");

  console.log("\nAll grid tests passed.");
  ```

- [ ] **Step 2: Run to confirm failure**
  ```bash
  node HabitWidget.test.js
  ```

- [ ] **Step 3: Implement `buildGrid`**

  Add after `dotTypeForValue`:
  ```js
  /**
   * Builds a grid from API response.
   * @param {object} apiResponse - { habitNames: string[], Habits: [...] }
   * @param {string[]} lastWeekDates - 7 "YYYY-MM-DD" strings (Mon→Sun)
   * @param {string[]} thisWeekDates - 7 "YYYY-MM-DD" strings (Mon→Sun)
   * @param {string} todayStr - "YYYY-MM-DD", future days in thisWeek → null
   * @returns {{ [habitName]: { lastWeek: dotType[7], thisWeek: dotType[7] } }}
   *   Keys are in habitNames array order.
   */
  function buildGrid(apiResponse, lastWeekDates, thisWeekDates, todayStr) {
    const { habitNames, Habits } = apiResponse;

    // Build date→{habitName→value} lookup
    const lookup = {};
    for (const entry of Habits) {
      const map = {};
      for (const h of entry.habits) map[h.name] = h.value;
      lookup[entry.date] = map;
    }

    const grid = {};
    for (const name of habitNames) {
      grid[name] = {
        lastWeek: lastWeekDates.map((d) =>
          dotTypeForValue((lookup[d] || {})[name] ?? null)
        ),
        thisWeek: thisWeekDates.map((d) => {
          if (d > todayStr) return "null"; // future day
          return dotTypeForValue((lookup[d] || {})[name] ?? null);
        }),
      };
    }
    return grid;
  }
  ```

  Update module.exports:
  ```js
  if (typeof module !== "undefined") module.exports = { getWeekDates, dotTypeForValue, buildGrid };
  ```

- [ ] **Step 4: Run all tests**
  ```bash
  node HabitWidget.test.js
  ```
  Expected: all PASS

- [ ] **Step 5: Commit**
  ```bash
  git add HabitWidget.js HabitWidget.test.js
  git commit -m "feat: add buildGrid with tests"
  ```

---

## Chunk 2: Data Fetching & Caching

### Task 4: Fetch with cache fallback

**Files:**
- Modify: `HabitWidget.js` — add `fetchData`

This task uses Scriptable APIs (`Request`, `FileManager`) which can't be unit tested. Implement and verify manually in Scriptable.

- [ ] **Step 1: Implement `fetchData` in `HabitWidget.js`**

  Add after `buildGrid`:
  ```js
  // ─── DATA FETCHING ────────────────────────────────────────────────────────

  const CACHE_PATH = FileManager.local().joinPath(
    FileManager.local().documentsDirectory(),
    "habit_cache.json"
  );

  async function fetchData() {
    try {
      const req = new Request(API_URL);
      const json = await req.loadJSON();
      if (!json || !json.habitNames) throw new Error("Invalid response");
      FileManager.local().writeString(CACHE_PATH, JSON.stringify(json));
      return json;
    } catch (e) {
      if (FileManager.local().fileExists(CACHE_PATH)) {
        try {
          return JSON.parse(FileManager.local().readString(CACHE_PATH));
        } catch (_) {
          return null; // corrupt cache
        }
      }
      return null; // no cache, no network
    }
  }
  ```

- [ ] **Step 2: Manual verification in Scriptable**
  - Paste the current `HabitWidget.js` content into a new Scriptable script
  - Set `API_URL` to your actual endpoint
  - Add at the bottom temporarily: `const d = await fetchData(); console.log(JSON.stringify(d));`
  - Run script — confirm JSON logs correctly
  - Remove the temporary line

- [ ] **Step 3: Commit**
  ```bash
  git add HabitWidget.js
  git commit -m "feat: add fetchData with cache fallback"
  ```

---

## Chunk 3: Widget Rendering

### Task 5: Widget renderer

**Files:**
- Modify: `HabitWidget.js` — add `buildWidget` and entry point

- [ ] **Step 1: Add `buildWidget` function**

  Add after `fetchData`:
  ```js
  // ─── RENDERING ────────────────────────────────────────────────────────────

  const COLORS = {
    background: new Color("#FFFFFF"),
    filled:     new Color("#000000"),
    outline:    new Color("#000000"),
    nullDot:    new Color("#CCCCCC"),
    habitName:  new Color("#666666"),
    header:     new Color("#999999"),
  };

  const PADDING   = 8;
  const WEEK_GAP  = 4;
  const DAYS      = ["M", "T", "W", "T", "F", "S", "S"];

  function dotSize(habitCount) {
    return habitCount <= 4 ? 8 : 6;
  }

  function addDot(stack, type, size) {
    const dot = stack.addImage(dotImage(type, size));
    dot.imageSize = new Size(size, size);
  }

  function dotImage(type, size) {
    const ctx = new DrawContext();
    ctx.size = new Size(size, size);
    ctx.opaque = false;
    ctx.respectScreenScale = true;

    if (type === "filled") {
      ctx.setFillColor(COLORS.filled);
      ctx.fillEllipse(new Rect(0, 0, size, size));
    } else if (type === "outline") {
      ctx.setStrokeColor(COLORS.outline);
      ctx.setLineWidth(1);
      ctx.strokeEllipse(new Rect(1, 1, size - 2, size - 2));
    } else {
      ctx.setFillColor(COLORS.nullDot);
      ctx.fillEllipse(new Rect(0, 0, size, size));
    }

    return ctx.getImage();
  }

  async function buildWidget() {
    const data = await fetchData();

    const widget = new ListWidget();
    widget.backgroundColor = COLORS.background;
    widget.setPadding(PADDING, PADDING, PADDING, PADDING);

    if (!data) {
      const t = widget.addText("No data");
      t.textColor = COLORS.habitName;
      t.font = Font.systemFont(12);
      return widget;
    }

    const today = new Date();
    const todayStr = today.toISOString().slice(0, 10);
    const { lastWeek, thisWeek } = getWeekDates(today);
    const grid = buildGrid(data, lastWeek, thisWeek, todayStr);
    const habitNames = data.habitNames;
    const ds = dotSize(habitNames.length);
    const spacing = 2;

    // ── Header row ──────────────────────────────────────────────────────────
    const headerRow = widget.addStack();
    headerRow.layoutHorizontally();
    headerRow.spacing = spacing;

    // Empty cell aligned with habit name column
    const nameColWidth = 38;
    headerRow.addSpacer(nameColWidth);

    // Day labels: last week
    for (const label of DAYS) {
      const t = headerRow.addText(label);
      t.font = Font.systemFont(7);
      t.textColor = COLORS.header;
      t.lineLimit = 1;
    }

    // Week gap
    headerRow.addSpacer(WEEK_GAP);

    // Day labels: this week
    for (const label of DAYS) {
      const t = headerRow.addText(label);
      t.font = Font.systemFont(7);
      t.textColor = COLORS.header;
      t.lineLimit = 1;
    }

    widget.addSpacer(2);

    // ── Habit rows ───────────────────────────────────────────────────────────
    for (const name of habitNames) {
      const row = widget.addStack();
      row.layoutHorizontally();
      row.spacing = spacing;

      // Habit name
      const nameText = row.addText(name);
      nameText.font = Font.systemFont(8);
      nameText.textColor = COLORS.habitName;
      nameText.lineLimit = 1;
      nameText.minimumScaleFactor = 0.7;
      row.addSpacer(nameColWidth - name.length * 4.5); // approximate fixed width

      // Last week dots
      for (const type of grid[name].lastWeek) {
        addDot(row, type, ds);
      }

      // Week gap
      row.addSpacer(WEEK_GAP);

      // This week dots
      for (const type of grid[name].thisWeek) {
        addDot(row, type, ds);
      }

      widget.addSpacer(2);
    }

    return widget;
  }
  ```

  > **Note:** The habit name column uses an approximate fixed-width spacer. If names vary widely in length, visual alignment may be off — acceptable for this iteration.

- [ ] **Step 2: Add entry point at bottom of `HabitWidget.js`**

  ```js
  // ─── ENTRY POINT ─────────────────────────────────────────────────────────
  const widget = await buildWidget();

  if (config.runsInWidget) {
    Script.setWidget(widget);
  } else {
    widget.presentSmall();
  }

  Script.complete();
  ```

- [ ] **Step 3: Manual verification in Scriptable**
  - Copy entire `HabitWidget.js` into Scriptable
  - Set `API_URL` to your real endpoint
  - Run in app and verify:
    - Dot grid renders with habit names on the left and weekday headers (M T W T F S S) above each block
    - Two 7-day blocks are visually separated by a gap
    - Filled dots (black), outline dots (empty), and gray dots (null/future) are visually distinct
    - Future days in the current week show as gray dots
    - With ≤ 4 habits: dots are larger (8pt); with > 4 habits: dots are smaller (6pt) — temporarily add dummy habits to verify
  - Add widget to home screen → confirm Small widget renders
  - Test offline fallback: disable network, run widget → shows cached data
  - Test no-cache + no-network: delete `habit_cache.json` from Scriptable documents, disable network, run widget → shows "No data"

- [ ] **Step 4: Run unit tests one more time to confirm nothing broke**
  ```bash
  node HabitWidget.test.js
  ```
  Expected: all PASS (Scriptable-specific code is guarded and won't run in Node)

- [ ] **Step 5: Commit**
  ```bash
  git add HabitWidget.js
  git commit -m "feat: add widget renderer and entry point"
  ```

---

## Final Checklist

- [ ] `node HabitWidget.test.js` — all tests pass
- [ ] Widget renders correctly in Scriptable (run in-app)
- [ ] Widget renders on home screen as Small widget
- [ ] Offline fallback works: disable network, run widget → shows cached data
- [ ] No-cache + no-network: shows "No data" text
