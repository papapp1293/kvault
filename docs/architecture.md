# Architecture

## Goal

Build a Redis-compatible in-memory KV store in Rust, and a live leaderboard
service on top of it. The store is the learning vehicle (data structures,
concurrency, persistence); the leaderboard is the proof that it works.

## Workspace

| Crate | Owns | Does not own |
| --- | --- | --- |
| `kv-core` | Data structures, expiry, persistence, benchmarks | Networking, HTTP |
| `kv-server` | RESP parsing/serialization, TCP accept loop, command dispatch | Storage internals |
| `leaderboard` | HTTP/WebSocket API, dashboard, score logic | Storage internals (talks to `kv-core` or to `kv-server` over RESP — decision open, see below) |

## Wire protocol: RESP

The server speaks Redis's RESP protocol (simple strings, errors, integers,
bulk strings, arrays). This is the single most important design decision: it
makes `redis-cli` and `redis-benchmark` work against kvault, so every claim
about performance is checkable with standard tools, and any Redis client
library can talk to it.

Reference: the RESP spec at redis.io/docs/latest/develop/reference/protocol-spec/.

## Store design

- **Strings** first: a hash map from keys to values, with per-key TTL metadata.
- **Hashes**: nested maps, for player profiles and board metadata.
- **Sorted sets**: skip lists, the way Redis does it — O(log n) insert and
  rank queries, which is what makes leaderboards fast.
- **Expiry**: lazy expiration on read plus an active background sweep. Getting
  this right (and measuring it) is a Phase 2 task.
- **Concurrency**: open decision, record in an ADR before Phase 2. Redis is
  single-threaded with an event loop; a Rust store can shard across threads.
  Start single-threaded (simpler, matches Redis's model), measure, then
  decide whether sharding earns its complexity.

## Persistence

- Append-only log (AOF): every write is journaled, replayed on startup.
- Snapshots (RDB-style): periodic full dumps so restarts don't replay the
  whole log. Phase 3.

## Leaderboard service

Reads and writes go through the store; the service owns no state of its own.

- `POST /boards/:id/scores` — submit a score (`{ player, score }`).
- `GET /boards/:id/top?n=10` — top N players with ranks.
- `GET /boards/:id/rank/:player` — one player's rank and score.
- `WS /boards/:id/live` — push rank changes as scores land (pub/sub).
- Seasonal boards: a board key with a TTL, so a season ends by expiring.

Open decision: the leaderboard can link `kv-core` directly (in-process, fastest,
simplest to demo) or talk to `kv-server` over RESP (proves the protocol, lets
the store scale independently). Start in-process; switch to RESP once the
server is solid. Record the switch in an ADR.

## Benchmarking

Two layers, both published in the README:

1. **Criterion** (`cargo bench -p kv-core`): micro-benchmarks of store
   operations — SET/GET round-trip, ZADD/ZRANGE, expiry sweep.
2. **`redis-benchmark`** (`scripts/bench-vs-redis.sh`): head-to-head against
   stock Redis on the same machine, same workload. Report throughput and
   p50/p99 latency. No cherry-picked workloads: publish the command used.

## What good looks like

- A README with real numbers and the commands that produced them.
- An ADR for every genuinely hard decision (concurrency model, persistence
  format, in-process vs RESP for the leaderboard).
- A dashboard screenshot in the repo that a stranger could understand in
  ten seconds.
