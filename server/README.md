# TaskMaster sync server (8c layer 1)

Dumb append-only sync log. Zero knowledge of tables, LWW, tasks, or any
domain logic — it validates auth + envelope shape, assigns sequence
numbers, appends to disk, and serves.

**Stack:** plain Dart (`dart:io` `HttpServer`), no third-party runtime
dependencies. Chosen over shelf/Dart Frog because a single LXC container
needs the smallest possible supply chain; the protocol is two endpoints
and does not justify a framework.

## Run

```bash
cd server
dart pub get

export SYNC_API_KEY='change-me'
export SYNC_LOG_PATH=/var/lib/taskmaster-sync/events.ndjson
export SYNC_PORT=8080
# Optional TLS (omit both for plain HTTP — logs an explicit warning):
# export SYNC_CERT_PATH=/etc/ssl/taskmaster/server.crt
# export SYNC_KEY_PATH=/etc/ssl/taskmaster/server.key

dart run bin/server.dart
```

## Endpoints

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `POST` | `/events` | Bearer | Append batch. Body `{ "events": [ {tableName,rowId,payload} ] }` → `{accepted, firstSeq, lastSeq}`. >200 events → **413**. Invalid envelope → **400**. |
| `GET` | `/events?since=<seq>&limit=<n>` | Bearer | Read log. `since` is **exclusive** (`seq > since`); missing/`0` = full log. Default limit **500**, max **1000**. → `{events, nextCursor, hasMore}`. |
| `GET` | `/health` | none | `{ "ok": true, "lastSeq": n }` |

Envelope (client `SyncEvent` JSON):

```json
{
  "tableName": "tasks",
  "rowId": "uuid-or-composite-key",
  "payload": { "…full row state, camelCase drift toJson…": "…" }
}
```

## Config (env)

| Variable | Default | Notes |
|----------|---------|-------|
| `SYNC_PORT` | `8080` | |
| `SYNC_HOST` | `0.0.0.0` | |
| `SYNC_API_KEY` | *(unset)* | Missing → `/events` always 401; `/health` still open |
| `SYNC_LOG_PATH` | `sync_events.ndjson` | NDJSON, one record per line |
| `SYNC_CERT_PATH` | *(unset)* | With `SYNC_KEY_PATH` → HTTPS |
| `SYNC_KEY_PATH` | *(unset)* | |

## Durability

Acknowledged appends are `flush()`ed before the HTTP 200 — a process
kill cannot lose acked events. Sequence numbers are recovered from the
log file on startup (max seq + 1).

## Tests

```bash
cd server
dart analyze
dart test
```

## systemd (example)

`/etc/systemd/system/taskmaster-sync.service`:

```ini
[Unit]
Description=TaskMaster dumb sync server
After=network.target

[Service]
Type=simple
User=taskmaster
WorkingDirectory=/opt/taskmaster-sync/server
ExecStart=/usr/bin/dart run bin/server.dart
Environment=SYNC_PORT=8080
Environment=SYNC_API_KEY=change-me
Environment=SYNC_LOG_PATH=/var/lib/taskmaster-sync/events.ndjson
Environment=SYNC_CERT_PATH=/etc/ssl/taskmaster/server.crt
Environment=SYNC_KEY_PATH=/etc/ssl/taskmaster/server.key
Restart=on-failure
KillSignal=SIGTERM
TimeoutStopSec=15

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now taskmaster-sync
```

## Docker (example run, no Dockerfile in repo)

```bash
docker run -d \
  --name taskmaster-sync \
  -p 8080:8080 \
  -e SYNC_API_KEY=change-me \
  -e SYNC_LOG_PATH=/data/events.ndjson \
  -e SYNC_CERT_PATH=/certs/server.crt \
  -e SYNC_KEY_PATH=/certs/server.key \
  -v taskmaster-sync-data:/data \
  -v /etc/ssl/taskmaster:/certs:ro \
  dart:3.5 \
  dart run /app/server/bin/server.dart
```

## Backlog (out of scope for layer 1)

- Real fsync syscall (power-loss durability)
- Multi-user auth (owner_id, tokens) — ARCHITECTURE.md SYNC
- Tombstone TTL / purge protocol
- Rate limiting
- Let's Encrypt (cert file path already supports ACME-produced files)
