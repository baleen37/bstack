# Scriptable Habit Tracker Widget — Design Spec

**Date:** 2026-03-17
**Status:** Approved

---

## Overview

A Scriptable **Small** widget that displays 2 weeks of habit data fetched from a Google Apps Script endpoint. Habits are shown as a dot grid — one row per habit, 14 columns for 14 days, split into two weekly blocks with a gap between them.

---

## Layout

```
      M  T  W  T  F  S  S    M  T  W  T  F  S  S
운동  ○  ●  ●  ○  ●  ●  ●    ●  ●  ●  ○  ●  ·  ·
독서  ●  ●  ○  ●  ●  ○  ●    ○  ●  ●  ●  ○  ·  ·
명상  ●  ○  ●  ●  ●  ●  ○    ●  ●  ○  ●  ●  ·  ·
```

- **Habit name column** — left side, ~40pt wide, truncated if needed
- **Day columns** — 14 columns total: 7 days (last week) + gap + 7 days (this week)
- **Week alignment** — Monday-start calendar weeks. Left block = last week (Mon–Sun), right block = this week (Mon–Sun). Future days in this week → gray (null).
- **Dot legend:**
  - `●` filled black — `true` or numeric `> 0`
  - `○` outline — `false` or `0`
  - `·` gray — `null` (no data recorded)
- **Future days within current week** — shown as null (gray)
- **Weekday header row** — `M T W T F S S` repeated above each week block

---

## Data Source

- **Endpoint:** Google Apps Script `doGet` URL, hardcoded as a constant at the top of the script
- **Response shape:**
  ```json
  {
    "habitNames": ["운동", "독서", "명상"],
    "Habits": [
      { "date": "2026-03-17", "habits": [{ "name": "운동", "value": true }, ...] }
    ]
  }
  ```
- **Date range used:** this week (Mon–Sun) and last week (Mon–Sun), calendar-aligned. Future days within the current week are shown as null (gray). Total days displayed: always 14 (7 + 7).

---

## Value Mapping

| Raw value | Type    | Display |
|-----------|---------|---------|
| `true`    | boolean | filled dot |
| `false`   | boolean | outline dot |
| `> 0`     | number  | filled dot |
| `0`       | number  | outline dot |
| `null`    | —       | gray dot |

---

## Caching

- On successful fetch, response JSON is saved to `FileManager.local()` as `habit_cache.json`
- On network failure or non-2xx response, the cached file is loaded instead
- Cache has no expiry — always attempts live fetch first; cache is only a fallback
- If no cache exists and fetch fails, widget displays a plain error text: `"No data"`

---

## Visual Style (Light Theme)

| Element         | Value                        |
|-----------------|------------------------------|
| Background      | white `#FFFFFF`              |
| Filled dot      | black `#000000`              |
| Outline dot     | black border, no fill        |
| Null dot        | gray `#CCCCCC`               |
| Habit name      | system font, ~8–9pt, `#666666` |
| Weekday header  | system font, ~7pt, `#999999` |
| Dot size        | 8pt if ≤ 4 habits, 6pt if > 4 habits               |
| Week gap        | 4pt horizontal space         |
| Widget padding  | 8pt                          |

---

## Constraints

- Widget size: **Small** (155 × 155pt)
- Habit order: matches `habitNames` array order from API (spreadsheet column order)
- Max habits displayed: determined by available height; no hard cap enforced in code
- URL: hardcoded constant — no Keychain, no widget parameter input

---

## File Structure

```
HabitWidget.js   — single Scriptable script file
```

No external dependencies. Runs entirely within Scriptable.
