---
name: learn-teachback
description: 5-minute learning check after a feature ships. Use after every feature. The teacher agent asks you to explain the change, corrects gaps, and connects it to system-design interviews.
---

# /learn-teachback

1. Delegate to the `teacher` agent with the diff or branch just shipped.
2. Teacher explains: data flow end to end, why this design over alternatives, where it breaks at 10x scale.
3. Teach-back: you explain it back in your own words. Teacher corrects gaps precisely.
4. Teacher gives the interview version: problem → constraints → design → tradeoffs → numbers.
5. Save one paragraph to `docs/learning/` (file per feature) so the lesson compounds.
6. If a real decision was made, follow up with `/write-adr`.

A feature isn't done until you can explain it. If the teach-back fails, that's a signal to simplify the code, not to skip the lesson.
