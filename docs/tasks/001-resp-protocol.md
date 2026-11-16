# 001 — RESP parser + PING/ECHO/SET/GET/DEL

## Title

Implement the RESP wire protocol and the first commands so `redis-cli` can talk to kv-server.

## Why

Everything else in the project stands on this: the store is only a Redis
replacement if real Redis clients can speak to it. This task also establishes
the crate boundary — `kv-server` owns the wire, `kv-core` owns storage.

## Scope

- In:
  - RESP parser (simple strings, errors, integers, bulk strings, arrays) and serializer, with unit tests.
  - A minimal in-memory string store in `kv-core` (HashMap-based, no TTL yet).
  - Command dispatch in `kv-server`: `PING`, `ECHO`, `SET`, `GET`, `DEL`.
  - `kv-server` handles a connection end-to-end: accept, parse, execute, reply, keep the connection open for pipelined commands.
  - Graceful handling of malformed input (error reply, connection stays open).
- Out (explicitly):
  - TTL/expiry (task 004), hashes (002), sorted sets (003), pub/sub (005), persistence (006/007).
  - Sharding / multi-threaded store (ADR decision, Phase 2).

## Acceptance criteria

- [ ] `redis-cli -p 6379 ping` returns `PONG`.
- [ ] `SET`/`GET` round-trip works from `redis-cli`, including values with spaces and binary-safe bulk strings.
- [ ] `DEL` removes a key; `GET` on a missing key returns nil.
- [ ] Malformed input gets an error reply and the connection stays usable.
- [ ] Unit tests cover the parser (all five RESP types, partial reads, bad input) and the store.
- [ ] `cargo test`, `cargo clippy -- -D warnings`, `cargo fmt --check`, `cargo build` all pass.

## Approach (optional)

- Read the RESP spec first (Context7 / redis.io protocol spec). Don't guess the framing.
- Put the parser in `kv-server` (it owns the wire) and the store in `kv-core`.
- Use `tokio::io::BufReader` + a small state machine or a hand-rolled incremental parser; avoid pulling in a parser-combinator crate for the first pass.
- Keep the store behind a trait so the concurrency model can change later without rewriting dispatch.

## Risks / open questions

- Partial reads: TCP delivers RESP frames in arbitrary chunks; the parser must handle a frame split across reads.
- Pipelining: clients send many commands without waiting; the read loop must not assume one command per read.

## Verification

```sh
cargo test && cargo clippy -- -D warnings && cargo fmt --check && cargo build
cargo run -p kv-server   # in one terminal
redis-cli -p 6379 ping                        # PONG
redis-cli -p 6379 set foo "hello world"       # OK
redis-cli -p 6379 get foo                     # "hello world"
redis-cli -p 6379 del foo                     # (integer) 1
```

Manual check: connect with `nc localhost 6379`, send `*1\r\n$4\r\nPING\r\n`, expect `+PONG\r\n`.
