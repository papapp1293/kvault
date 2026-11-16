---
name: implement-tdd
description: Implement one approved plan test-first. Use after /plan-feature is approved. Red/green/refactor, small diffs, verification before finishing.
---

# /implement-tdd

1. Confirm there is an approved plan. If not, run `/plan-feature` first.
2. Work on a branch or git worktree, never on `main`.
3. For each step in the plan:
   - **Red:** write a failing test that pins the behavior.
   - **Green:** write the minimal code to pass it.
   - **Refactor:** clean up, keeping tests green.
4. Match existing repo patterns. TypeScript strict. Validate inputs at boundaries.
5. Run `npm run typecheck`, `npm run lint`, and the affected tests. Fix failures, don't skip them.
6. Report: files changed, tests added/passing, commands run, anything unresolved.
7. Next step is `/verify`, then `/review-pr`. Don't merge your own work.
