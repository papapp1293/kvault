# kvault

An in-memory key-value store in Rust, built to understand how Redis works —
plus a live leaderboard service on top of it, so the store is a product you
can demo, not just a library.

The store speaks the Redis wire protocol (RESP), so `redis-cli` and
`redis-benchmark` work against it with no changes. Benchmarks against real
Redis are published below as they land.

## Layout

```
crates/kv-core/       the storage engine: data structures, TTL/expiry, persistence
crates/kv-server/     the RESP wire server (tokio) — redis-cli connects here
crates/leaderboard/   live leaderboard service (axum) + dashboard, backed by the store
docs/                 architecture, task queue, ADRs, learning notes
```

```
redis-cli ──RESP──▶ kv-server ──▶ kv-core (strings, hashes, sorted sets)
                                         ▲
dashboard ──HTTP/WS──▶ leaderboard ──────┘
```

## Status

Scaffold. The workspace compiles, the leaderboard serves a dashboard shell on
`:3000`, and `kv-server` binds on `:6379` but does not speak RESP yet. The
first real feature is task 001 (RESP parser + PING/SET/GET). See
`docs/tasks/queue.md` for the roadmap.

## Roadmap

- [ ] **Phase 1 — the store speaks Redis.** RESP parser + serializer, strings,
      `SET`/`GET`/`DEL`, `PING`/`ECHO`. `redis-cli` connects.
- [ ] **Phase 2 — structures.** Hashes, sorted sets (skip list), TTL/expiry.
- [ ] **Phase 3 — persistence.** Append-only log + snapshots, crash recovery.
- [ ] **Phase 4 — the leaderboard.** Score API, live ranks over WebSocket,
      TTL'd seasonal boards, dashboard.
- [ ] **Phase 5 — numbers.** Criterion benches + `redis-benchmark` head-to-head
      vs real Redis, published here.

## Commands

```sh
cargo build              # build the workspace
cargo test               # unit + integration tests
cargo clippy -- -D warnings
cargo fmt --check
cargo bench -p kv-core   # criterion benchmarks
cargo run -p kv-server        # RESP server on 127.0.0.1:6379
cargo run -p leaderboard      # dashboard + API on 127.0.0.1:3000
./scripts/bench-vs-redis.sh  # head-to-head vs real Redis (needs Phase 1)
```

Requires a Rust toolchain: `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`

## Benchmarks

_Empty until Phase 1 lands. Target: publish p50/p99 latency and throughput
for SET/GET and ZADD/ZRANGE, measured with `redis-benchmark` against both
kvault and stock Redis on the same machine._

## Why this project

In-memory storage is the backbone of low-latency systems, and the only way to
really understand it is to build one: hash table design, skip lists, expiry
sweeps, the event loop, and what persistence costs. The leaderboard exists so
every one of those pieces has a visible, demo-able payoff.
