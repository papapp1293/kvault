# Task queue

Work the top unchecked item first. A task is batch-eligible only when its spec
file exists and is complete (see `TEMPLATE.md`). One task per branch, one
agent run per task.

- [ ] 001 — RESP parser + PING/ECHO/SET/GET/DEL — spec: `001-resp-protocol.md`
- [ ] 002 — Hashes (HSET/HGET/HGETALL) — spec needed
- [ ] 003 — Sorted sets via skip list (ZADD/ZRANGE/ZRANK) — spec needed
- [ ] 004 — TTL + expiry: lazy + active sweep — spec needed
- [ ] 005 — Pub/sub (SUBSCRIBE/PUBLISH) — spec needed
- [ ] 006 — AOF persistence + replay on startup — spec needed
- [ ] 007 — Snapshots (RDB-style dumps) — spec needed
- [ ] 008 — Leaderboard score API (submit/top/rank) — spec needed
- [ ] 009 — Live ranks over WebSocket + dashboard updates — spec needed
- [ ] 010 — Benchmarks: criterion suite + redis-benchmark head-to-head — spec needed
