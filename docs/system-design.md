# kvault — System Design

This is the overall design: every function the system will have, every
component, and the decisions behind them. Read this before any task plan.
Per-task plans (`docs/tasks/`) fit inside this design; they don't replace it.
A visual version with diagrams lives in the companion artifact (see README).

## 1. What we're building

**kvault** is an in-memory key-value store in Rust that speaks the Redis wire
protocol (RESP), plus a **live leaderboard service** built on top of it.

Goals:

- A store real Redis clients can talk to (`redis-cli`, `redis-benchmark`,
  any Redis client library), so every performance claim is checkable.
- A leaderboard service that makes the store demonstrable: scores, ranks,
  live updates, seasonal boards.
- Code and docs a big-tech interviewer would respect: benchmarks with real
  numbers, ADRs for hard decisions, tests that pin behavior.

Non-goals (for now):

- Clustering / replication. Single node only.
- Redis Cluster protocol, transactions (MULTI/EXEC), Lua scripting.
- Eviction policies (maxmemory). The store grows until the operator says
  otherwise; eviction is a possible later task.

## 2. The full function surface

Every command and endpoint the finished system supports. Nothing here is
aspirational — each maps to a queued task.

### Connection

| Command | What it does | Task |
| --- | --- | --- |
| `PING [msg]` | Health check, returns `PONG` (or echoes `msg`) | 001 |
| `ECHO msg` | Returns `msg` | 001 |

### Strings

| Command | What it does | Task |
| --- | --- | --- |
| `SET key value [EX secs] [PX ms] [NX \| XX]` | Store a string, with optional TTL and set-if conditions | 001 (+004 for TTL) |
| `GET key` | Read a string; nil if missing or expired | 001 |
| `DEL key [key ...]` | Delete keys; returns how many existed | 001 |
| `EXISTS key [key ...]` | Count how many of the keys exist | 001 |
| `INCR key` / `DECR key` | Atomically add/subtract 1 (values are integers) | 002 |
| `APPEND key value` | Append to a string | 002 |

### Hashes

| Command | What it does | Task |
| --- | --- | --- |
| `HSET key field value [field value ...]` | Set fields in a hash | 002 |
| `HGET key field` | Read one field | 002 |
| `HGETALL key` | Read all fields | 002 |
| `HDEL key field [field ...]` | Delete fields | 002 |

### Sorted sets (the leaderboard's engine)

| Command | What it does | Task |
| --- | --- | --- |
| `ZADD key score member [score member ...]` | Add/update members with scores | 003 |
| `ZRANGE key start stop [WITHSCORES]` | Members by rank range (top-N) | 003 |
| `ZREVRANGE key start stop [WITHSCORES]` | Same, highest score first | 003 |
| `ZRANK key member` / `ZREVRANK key member` | A member's rank | 003 |
| `ZSCORE key member` | A member's score | 003 |
| `ZREM key member [member ...]` | Remove members | 003 |
| `ZCARD key` | How many members | 003 |

### TTL / expiry

| Command | What it does | Task |
| --- | --- | --- |
| `EXPIRE key secs` / `PEXPIRE key ms` | Set a TTL on any key | 004 |
| `TTL key` / `PTTL key` | Time left on a key (-1 no TTL, -2 missing) | 004 |
| `PERSIST key` | Remove a key's TTL | 004 |

### Pub/sub

| Command | What it does | Task |
| --- | --- | --- |
| `SUBSCRIBE channel [channel ...]` | Listen on channels (connection enters subscribe mode) | 005 |
| `PUBLISH channel message` | Send a message to all subscribers | 005 |
| `UNSUBSCRIBE [channel ...]` | Stop listening | 005 |

### Persistence / server

| Command | What it does | Task |
| --- | --- | --- |
| `BGSAVE` | Snapshot the store to disk in the background | 007 |
| `FLUSHALL` | Delete everything (dangerous; for tests/dev) | 001 |

### Leaderboard HTTP API

| Endpoint | What it does | Task |
| --- | --- | --- |
| `POST /boards/:id/scores` `{player, score}` | Submit a score | 008 |
| `GET /boards/:id/top?n=10` | Top N players with ranks | 008 |
| `GET /boards/:id/rank/:player` | One player's rank + score | 008 |
| `GET /boards/:id` | Board metadata (player count, season end) | 008 |
| `WS /boards/:id/live` | Live rank updates as scores land | 009 |
| `POST /boards/:id/season` | Start a new season (new board key, old one expires) | 009 |

## 3. System overview

```
redis-cli ──┐
redis-benchmark ─┤
any Redis client ┤            ┌─────────────────────┐
                 └─ RESP ───▶ │ kv-server :6379     │
                              │  accept loop        │
                              │  RESP parser        │  ┌──────────────────┐
                              │  command dispatch ──┼─▶│ kv-core (store)  │
                              └─────────────────────┘  │  strings         │
                                                       │  hashes          │
browser ── HTTP/WS ──▶ leaderboard :3000 ─────────────▶│  sorted sets     │
                        │  score API                   │  expiry          │
                        │  WebSocket fan-out           │  pub/sub         │
                        │  dashboard (static)          │  AOF + snapshots │
                        └──────────────────────────────┴──────────────────┘
```

Three crates, three jobs. `kv-core` owns data and knows nothing about
sockets. `kv-server` owns the wire and knows nothing about storage internals.
`leaderboard` owns the product and no state of its own.

## 4. kv-server — the wire

One Tokio task per connection. The accept loop binds `:6379`, accepts a
socket, and spawns a task that runs until the client disconnects.

Each connection task does a loop:

1. **Read** bytes into a buffer. TCP delivers RESP frames in arbitrary
   chunks, so the parser must handle a frame split across reads.
2. **Parse** one complete RESP frame into a command + arguments. The parser
   is incremental: it consumes what it can and waits for more bytes when a
   frame is incomplete.
3. **Dispatch**: match the command name, call the store, build a RESP reply.
4. **Write** the reply. Pipelining is supported: a client may send many
   commands without waiting, and the loop answers them in order.

### Full-duplex, in plain language

A TCP connection is **full-duplex**: data flows both directions at the same
time, independently. The server can be reading your next command while still
writing the previous reply. Tokio expresses this by letting you **split** a
socket into a read half and a write half, each owned by different code. For
most commands the loop above is enough (read, then write, in order). The
split matters for **pub/sub**: a subscribed connection must receive published
messages at any moment, even while it's not sending anything — so one task
owns the read half (listening for UNSUBSCRIBE) while another owns the write
half (pushing messages). That's the only place the split is load-bearing.

## 5. kv-core — the store

### The core data structure

Everything is a key pointing at a **value** (string, hash, or sorted set),
plus optional expiry metadata. The store is one big map:

```
keys: HashMap<String, Entry>
Entry { value: Value, expires_at: Option<Instant> }
Value = String(Bytes) | Hash(HashMap) | SortedSet(SkipList)
```

### Strings

Plain byte strings in the map above. `INCR`/`DECR` parse the bytes as
integers, do the math, and write back — atomically, because the whole
operation happens under one lock acquisition (see §7).

### Hashes

A nested map: key → field → value. Used for player profiles and board
metadata. Implementation is a `HashMap` inside the `Value` enum; nothing
exotic, which is the point — hashes teach the "value types in one map"
pattern that the rest of the store builds on.

### Sorted sets — the skip list

The leaderboard lives or dies on sorted sets: insert a score, ask for the
top 10, ask for one player's rank — all fast, even with millions of players.

A sorted set needs three operations to be fast: insert by score, read by
rank range, and find a member's rank. A plain sorted array is O(n) on
insert; a balanced tree is complex to implement correctly. Redis uses a
**skip list**, and so do we: a layered linked list where each level skips
ahead further, giving O(log n) insert, lookup, and rank with much simpler
code than a tree. The skip list is also paired with a hash map
(member → score) so `ZSCORE` and `ZADD`-updates are O(1) lookups before
the list is touched.

Why this matters for learning: the skip list is the single most
interview-relevant data structure in the project. Task 003 is where the
deepest learning happens.

### Expiry

Two mechanisms, like Redis:

- **Lazy**: on any read, if the key is past `expires_at`, treat it as
  missing and delete it. Free, but only cleans keys people touch.
- **Active**: a background task wakes up periodically (e.g. every 100ms),
  samples a handful of keys with TTLs, and deletes the expired ones. This
  bounds memory growth from keys nobody reads again.

Seasonal leaderboard boards are just keys with a TTL: when the season ends,
the board key expires.

### Pub/sub

Channels map to sets of subscribers. `PUBLISH` looks up the channel and
sends the message to each subscriber's queue; subscribers are connection
tasks with a write half (see §4). Messages are fire-and-forget: if nobody
is subscribed, the message is dropped. No persistence, no replay.

## 6. Persistence

Memory is fast and forgetful. Two mechanisms, like Redis:

- **AOF (append-only log)**: every write command is appended to a log file
  as it happens. On startup, the server replays the log to rebuild the
  store. Durable, but replay time grows with history.
- **Snapshots**: periodically, the whole store is written to a compact dump
  file (`BGSAVE` does this in the background). On startup, load the newest
  snapshot, then replay only the AOF entries written after it.

Recovery order on startup: load snapshot → replay AOF → accept connections.
AOF fsync policy is an open decision (every write vs every second); see §11.

## 7. Concurrency model

### The decision

**Start single-threaded, like Redis.** One event loop owns the store; each
command runs to completion without interruption. No locks on the hot path,
no data races by construction, and the mental model is simple: commands are
atomic because nothing else runs during them.

This is a deliberate, reversible choice, recorded in an ADR when task 002
lands. If benchmarks later show the single loop is the bottleneck, the
upgrade path is **sharding**: N independent stores, each with its own loop,
with keys assigned to shards by hash. Sharding keeps the simple model per
shard and scales with cores — but it complicates cross-shard operations
(there are none in the current command set, which is part of why it's a
clean future step).

### `Mutex<HashMap>`, in plain language

You'll see this type in Rust code for shared state, so here's what it means
in one paragraph. A `HashMap` is just the map. A `Mutex` is a lock wrapped
around it: to touch the map, a thread must first **lock** the mutex, and
while one thread holds the lock, every other thread waits. In Rust the lock
is special because the mutex **owns** the map — the compiler won't let you
touch the data without holding the lock, so data races are a compile error,
not a runtime bug. You lock it, do your work, and the lock releases when the
guard goes out of scope. `Arc` is the companion piece: a shared, reference-
counted pointer that lets multiple threads own the same mutex safely.

In kvault's single-threaded design, the store does **not** need a
`Mutex<HashMap>` on the hot path — the event loop owns the map outright.
Mutexes appear at the edges: the pub/sub subscriber registry (written from
many connection tasks) and any shared metrics. When you see one, it's a
sign that the data is genuinely shared, and the lock is the price of that.

## 8. Leaderboard service

The service owns no state. Every read and write goes to the store.

**Data model** (keys in the store):

- `board:{id}:scores` — sorted set, member = player, score = points.
- `board:{id}:meta` — hash: `name`, `season`, `ends_at`.
- `board:{id}:events` — pub/sub channel for live updates.

**Flows:**

- Submit a score: `ZADD board:{id}:scores <score> <player>`, then
  `PUBLISH board:{id}:events <update>` so live watchers get it.
- Top N: `ZRANGE board:{id}:scores 0 <n-1> WITHSCORES` (reversed).
- Rank: `ZREVRANK` + `ZSCORE`.
- Live: the WebSocket handler subscribes to the board's events channel and
  forwards updates to the browser; the dashboard re-renders ranks.
- New season: create `board:{id}:scores` under a new season key and set a
  TTL on the old one.

**In-process vs RESP (open decision):** the service can link `kv-core`
directly (fastest, simplest demo) or talk to `kv-server` over RESP (proves
the protocol, lets the store scale independently). Start in-process; switch
to RESP once the server is solid. Record the switch in an ADR.

## 9. Benchmarking

Two layers, both published in the README with the exact commands used:

1. **Criterion** (`cargo bench -p kv-core`): micro-benchmarks — SET/GET
   round-trip, ZADD/ZRANGE, expiry sweep. Measures the store, not the network.
2. **`redis-benchmark`** (`scripts/bench-vs-redis.sh`): head-to-head against
   stock Redis on the same machine, same workload. Report throughput and
   p50/p99 latency.

Targets (goals, not promises): within 2x of Redis throughput on SET/GET,
p99 under 1ms on local loopback for leaderboard reads.

## 10. Build order

| Phase | Tasks | What it proves |
| --- | --- | --- |
| 1. The store speaks Redis | 001 | A real client connects and gets answers |
| 2. Structures | 002, 003, 004 | Hashes, skip lists, expiry — the core |
| 3. Real-time + durable | 005, 006, 007 | Pub/sub, AOF, snapshots |
| 4. The product | 008, 009 | Leaderboard API, live dashboard |
| 5. Numbers | 010 | Benchmarks vs Redis, published |

## 11. Open decisions (ADRs to write)

These are the judgment calls. Each gets an ADR when its task starts — and
each is a decision **you** should weigh in on, not something to rubber-stamp:

1. **Concurrency model**: single-threaded loop vs sharded stores (§7).
   Default: single-threaded. Revisit after Phase 2 benchmarks.
2. **AOF fsync policy**: every write (safest, slowest) vs every second
   (Redis default, may lose 1s of writes) vs OS-managed.
3. **Snapshot format**: custom binary vs a serialization crate (bincode,
   rkyv). Custom is more educational; a crate is less code.
4. **Leaderboard transport**: in-process `kv-core` vs RESP to `kv-server` (§8).
5. **Eviction**: add a maxmemory policy later, or leave unbounded? (Only
   matters if the demo ever runs long-lived with real traffic.)
6. **Key encoding**: bytes (Redis-like, any binary key) vs UTF-8 strings
   (simpler, rejects non-UTF8 keys). Redis uses bytes; matching it is more
   correct and more work in the parser.

## 12. Glossary

- **RESP**: Redis's wire protocol — the byte format clients and servers use
  to talk. Five types: simple strings, errors, integers, bulk strings, arrays.
- **Event loop**: a single thread that waits for I/O events (a socket has
  data, a timer fired) and handles them one at a time. No threads per
  connection; that's how one thread serves thousands of clients.
- **Full-duplex**: both directions of a connection usable at the same time
  (§4).
- **Mutex**: a lock that lets one thread at a time touch some data (§7).
- **Arc**: a shared pointer that lets multiple threads own the same data;
  the data is freed when the last owner drops it.
- **Skip list**: a layered linked list with O(log n) insert/lookup/rank (§5).
- **AOF**: append-only log of write commands, replayed on startup (§6).
- **Pipelining**: a client sending many commands without waiting for replies.
- **p50/p99 latency**: the latency that 50% / 99% of requests beat. p99 is
  the number that matters for "how slow does it feel when it's slow."
