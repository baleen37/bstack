# Example: CLI change

Change: `mytool export` gains a `--from <date>` flag.

Handle: `bun run build` (setup, not a step), then run the built binary.
Isolate state: `export HOME=$(mktemp -d)` if the tool writes config.

Steps:

1. ✅ `./dist/mytool export --from 2026-01-01` → 3 rows, all dated ≥ 2026-01-01
   ```
   $ ./dist/mytool export --from 2026-01-01
   2026-01-04  ok
   2026-02-11  ok
   2026-03-02  ok
   ```
2. ✅ `./dist/mytool export` (no flag) → same 5 rows as before the change
3. 🔍 `./dist/mytool export --from ''` → `error: --from requires a value`, exit 2
4. 🔍 `./dist/mytool export --form 2026-01-01` (typo) → error names the unknown flag

Interactive CLI or TUI? Run it in an isolated tmux server and capture the pane:

```bash
tmux -L verify new-session -d -s v -x 120 -y 40 './dist/mytool'
tmux -L verify send-keys -t v 'export' Enter
tmux -L verify capture-pane -t v -p
tmux -L verify kill-server
```
