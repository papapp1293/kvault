---
name: review-pr
description: Independent review of a diff or branch before opening a PR. Use before every PR. Delegates to the reviewer subagent for a ranked, actionable review.
---

# /review-pr

1. Delegate to the `reviewer` subagent with the branch/diff range (default: `git diff main...HEAD`).
2. The reviewer returns findings ranked Blocker / Should fix / Nit, each with file + line and a concrete fix, plus a verdict: Approve / Approve with nits / Request changes.
3. Fix Blockers and Should-fix items. Nits are your call.
4. Re-run review on the updated diff if Blockers were fixed.
5. Only then open the PR, with a clear title, what/why, how to test, and screenshots for UI changes.
