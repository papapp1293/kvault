# Task queue — how batch work stays safe

`queue.md` is the single queue for supervised + scheduled work. Rules:

1. **Spec first.** Every queue line links to a spec file (this folder) or a GitHub issue with acceptance criteria. No spec, no run.
2. **One task per run.** The loop does one task, verifies it, marks it done, stops. It never batches tasks into a single pass.
3. **Small and verifiable.** If you can't state how to verify it in one line, split the task.
4. **Branches only.** Work lands on a branch + PR. Nothing auto-merges to `main`.
5. **Stop on red.** First failing verification stops the loop. A human looks before it resumes.
6. **Max N per run.** Default 10 passes. M-scheduled runs will use a smaller cap (start with 3).

Queue format (`queue.md`):

```md
- [ ] Add health-check endpoint — spec: docs/tasks/001-health-check.md
- [ ] Add load test for bid path — spec: docs/tasks/002-bid-load-test.md
```

The batch loop picks the first unchecked line. Mark it `- [x]` only after verification passes.
