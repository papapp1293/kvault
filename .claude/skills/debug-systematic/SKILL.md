---
name: debug-systematic
description: Systematic debugging for a failing test, crash, or wrong behavior. Use when stuck or when a quick fix didn't work. Reproduces first, then bisects, then fixes with a regression test.
---

# /debug-systematic

1. **Reproduce first.** Write the smallest reproduction (failing test or minimal steps). If you can't reproduce it, say so — don't guess-fix.
2. **Narrow.** Bisect: what changed recently? Which layer (UI / API / DB / queue / cache)? Use the `researcher` subagent for wide searches so the main context stays clean.
3. **Hypothesize, then test.** One hypothesis at a time. Log or test to confirm before changing code.
4. **Fix + regression test.** The fix lands with a test that fails without it.
5. **Explain.** One paragraph: root cause, why it wasn't caught, what prevents recurrence. Save it to `docs/learning/` if it's a pattern worth remembering.

Never "fix" by deleting the failing test or loosening an assertion without understanding why it failed.
