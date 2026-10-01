# Example: Server / API change

Change: `POST /orders` now rejects a missing `quantity` with 400.

Handle: start the server on a free port in the background, wait for it to be
ready, and stop it at the end. Never reuse a port another process owns.

```bash
PORT=$(python3 -c 'import socket;s=socket.socket();s.bind(("",0));print(s.getsockname()[1])')
PORT=$PORT bun run start > /tmp/verify-server.log 2>&1 &
SERVER_PID=$!
until curl -fsS "localhost:$PORT/health" >/dev/null; do sleep 0.5; done
```

Steps:

1. ✅ `curl -sS -XPOST localhost:$PORT/orders -d '{"sku":"a","quantity":1}'` → 201, body has `id`
2. ✅ `curl -sS -XPOST localhost:$PORT/orders -d '{"sku":"a"}'` → 400, `{"error":"quantity is required"}`
3. 🔍 `quantity: 0` → 400 (not treated as missing-but-ok)
4. 🔍 `GET /orders` (wrong method) → 405, unchanged from before

Capture the response bodies inline in the report, plus any server log lines
that looked off. Then `kill $SERVER_PID`.
