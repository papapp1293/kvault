# Rust primer — just enough for kvault

You've never used Rust. This is not a Rust course — it's the seven ideas you
need to read and write kvault's code, each tied to where it appears in the
repo. Learn them in order; each one unlocks the next. For depth, the official
book (doc.rust-lang.org/book) is excellent, but you don't need to read it
cover to cover before starting task 001.

## 1. Ownership and borrowing (the one big idea)

Every value in Rust has exactly one **owner**. When the owner goes out of
scope, the value is freed — no garbage collector, no manual `free`. You can
**borrow** a value (lend a reference, `&value`) without giving it away, but
the compiler enforces the rules: many readers **or** one writer, never both
at once. Most Rust compile errors are the compiler enforcing this, and they
are usually telling you something real about your program.

Where you'll see it: everywhere. The store owns its `HashMap`; commands
borrow keys to look things up. When task 001's code fights you about
"borrowed value does not live long enough," that's this rule, and the fix is
usually to clone the small thing or restructure who owns what.

## 2. Option and Result (no null, no exceptions)

Rust has no `null` and no exceptions. Instead:

- `Option<T>` is `Some(value)` or `None` — a value that might be absent.
  `GET` on a missing key returns `None`. You must handle both cases; the
  compiler won't let you forget.
- `Result<T, E>` is `Ok(value)` or `Err(error)` — a value or a failure.
  Functions that can fail return `Result`, and the `?` operator propagates
  errors upward: `let x = fallible()?;` returns early on error.

Where you'll see it: `kv-core` lookups return `Option`; I/O and parsing
return `Result`. The `?` in `main.rs` is how `anyhow::Result` works.

## 3. Structs, enums, and match

- **Structs** group fields, like a class with only data.
- **Enums** are values that are one of several variants — and each variant
  can carry different data. The store's `Value` enum (`String`, `Hash`,
  `SortedSet`) is the core example: one key can hold any of three types.
- **`match`** is how you handle enums: it forces you to cover every variant,
  so adding a new value type breaks the build until every handler is updated.
  That's a feature.

## 4. Traits (shared behavior)

A trait is a set of methods a type promises to implement — like an interface
in TypeScript/C#. Traits are how Rust does polymorphism without inheritance.
You'll meet them as bounds (`T: Clone`) and as the way the store's
components plug together (e.g. a persistence backend trait with AOF and
snapshot implementations).

## 5. Arc and Mutex (sharing across threads)

- **`Arc<T>`** is a reference-counted pointer: many owners, the value is
  freed when the last one drops. `Arc` is how data is shared between threads.
- **`Mutex<T>`** is a lock around data: lock it, use the data, the lock
  releases when the guard drops. In Rust the mutex **owns** the data, so you
  literally cannot touch it without holding the lock — data races become
  compile errors.

Where you'll see it: `Arc<Mutex<...>>` around the pub/sub subscriber registry
and metrics. The hot-path store doesn't use a mutex (single-threaded event
loop — see `system-design.md` §7). If you see a mutex, ask: "what threads
share this, and why?"

## 6. async/await and Tokio

Network code waits a lot (for bytes, for timers). Instead of one OS thread
per connection, Rust uses **async tasks**: small units of work the Tokio
runtime parks while they wait and resumes when data arrives. `async fn`
declares such work; `.await` is where it can pause. `#[tokio::main]` sets
up the runtime; `tokio::spawn` starts a task (one per connection in
`kv-server`).

Mental model: async is not parallelism — it's efficient waiting. One thread
can juggle thousands of connections because most of them are idle most of
the time. Parallelism comes from Tokio's multi-threaded runtime, which runs
tasks across cores.

## 7. Modules, crates, and the workspace

- A **crate** is a compilation unit: a library (`lib.rs`) or a binary
  (`main.rs`). kvault has three crates in one **workspace** (see root
  `Cargo.toml`): `kv-core`, `kv-server`, `leaderboard`.
- A **module** (`mod`) is a file or folder inside a crate. `pub` makes
  things visible outside the module; everything is private by default.
- **`use`** brings names into scope. Paths use `::` (`tokio::net::TcpListener`).
- **Cargo** is the build tool: `cargo build`, `cargo test`, `cargo clippy`,
  `cargo fmt`, `cargo bench`. `Cargo.toml` declares dependencies;
  `Cargo.lock` pins exact versions.

## How to read Rust code (quick orientation)

- Types come after colons: `let count: usize = 0;` (often inferred, so
  you'll see `let count = 0;`).
- `::` is a path separator: `std::collections::HashMap`.
- `!` after a name means a macro, not a function: `println!`, `vec!`.
- `&` borrows, `&mut` borrows mutably. `*` dereferences.
- `impl` blocks define methods on a type.
- Doc comments (`///`) are the norm on public items — read them first.

## Your first week with Rust (through kvault)

1. Read the scaffold in this order: `crates/kv-core/src/lib.rs`,
   `crates/kv-server/src/main.rs`, `crates/leaderboard/src/main.rs`.
   They're short; note what confuses you and ask the teacher agent.
2. Task 001 is your Rust tutorial: the RESP parser teaches enums, `match`,
   `Result`, and byte handling; the store teaches `HashMap` and ownership.
3. After each task, run `/learn-teachback` and explain the Rust concept
   back in your own words — that's the part that makes it stick.
4. When the compiler rejects your code, read the error fully. Rust's errors
   are famously helpful and usually suggest the fix.
