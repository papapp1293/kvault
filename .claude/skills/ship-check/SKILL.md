---
name: ship-check
description: Pre-ship checklist before opening a PR or deploying. Use before every PR. Runs typecheck, lint, tests, secret scan, and confirms docs/changelog are updated.
---

# /ship-check

Run every check. Stop on the first failure and fix it.

1. `npm run typecheck` — must pass.
2. `npm run lint` — must pass.
3. `npm test` — must pass. `npm run test:e2e` for user-facing flows.
4. `npm run build` — must pass.
5. Secret scan: `git diff --cached` contains no tokens, keys, or `.env` contents.
6. Docs: README updated if behavior/commands changed. Changelog entry added if the repo has one.
7. PR description drafted: what, why, how to test, screenshots for UI.
8. If a real decision was made, `/write-adr` is done or queued.

Report pass/fail per step. Don't open the PR until all steps pass.
