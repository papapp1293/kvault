# AGENTS.md — canonical agent instructions

This file is the single source of truth for AI coding agents in this repo.
`CLAUDE.md` is a symlink to this file. Codex reads this file natively.
Keep this file under ~60 lines. Procedures live in `.claude/skills/`, not here.

## Project
- Stack: Rust (tokio, axum, criterion), workspace with three crates: `kv-core`
  (storage engine), `kv-server` (RESP wire server), `leaderboard` (HTTP/WS service).
- Goal: a Redis-compatible in-memory KV store + live leaderboard service.
  Portfolio-quality code a big-tech interviewer would respect. Clean, tested,
  benchmarked, explained. See `docs/architecture.md` before changing design.

## Commands
- Build: `cargo build` (workspace) / `cargo build -p <crate>`
- Tests: `cargo test` (must pass before any PR)
- Lint: `cargo clippy -- -D warnings` (must pass before any PR)
- Format: `cargo fmt` / check with `cargo fmt --check`
- Bench: `cargo bench -p kv-core` (criterion)
- Run server: `cargo run -p kv-server` (RESP on 127.0.0.1:6379)
- Run leaderboard: `cargo run -p leaderboard` (dashboard on 127.0.0.1:3000)

## Rules
- Plan before multi-file edits. Use `/plan-feature`. One-line fixes don't need a plan.
- TDD for new behavior: failing test first, then minimal implementation, then refactor.
- Small, reviewable diffs. One feature per branch, one task per agent run.
- Never commit secrets, tokens, or `.env` contents. Never print them.
- Never push directly to `main`. Work on a branch, open a PR, let review happen.
- Never hand-edit `Cargo.lock` or generated files. Use the tool that owns them.
- Prefer the existing patterns in this repo over inventing new ones. Match surrounding code.
- Use Context7 for version-specific library docs. Don't guess APIs from training data.
- After every feature: run `/verify` (build + launch + observe), then `/learn-teachback`.
- Record real decisions in `docs/decisions/` via `/write-adr`.
- Benchmark hot paths with criterion. Performance claims need numbers + the command that produced them.

## Code style
- No `unwrap()`/`expect()` in library code (`kv-core`). Return `Result` with
  `anyhow`/`thiserror`. `unwrap` in tests and tiny binaries is fine.
- No `unsafe` without a comment explaining why it's sound, plus a test.
- Public APIs get doc comments. Deterministic logic lives in `kv-core` with unit tests.
- Errors are explicit and typed. No silent catches, no empty fallbacks that hide failures.
- `rustfmt` everywhere; clippy pedantic is a goal, warnings are a failure.

## What good looks like
- A PR a stranger could review: clear title, what/why, how to test, benchmark numbers for perf work.
- A README that explains the architecture and shows real benchmark numbers.
- Tests that pin the behavior you'd demo in an interview.
