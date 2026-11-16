---
name: plan-feature
description: Plan a feature before any multi-file edit. Use when starting a feature, refactor, or unfamiliar change. Produces a written, approvable plan via the planner agent.
---

# /plan-feature

1. Delegate read-only exploration to the `planner` subagent. Include: the feature goal, any constraints, and links to relevant issues/specs in `docs/tasks/`.
2. The planner returns: goal, scope in/out, files to change, ordered steps, tests to add, risks, open questions, verification steps.
3. Present the plan to the user. Do not start implementing until they approve or amend it.
4. Save the approved plan to `docs/tasks/<slug>-plan.md` so batch runs and future sessions can reuse it.

Skip this skill for one-line fixes. Use it for everything else.
