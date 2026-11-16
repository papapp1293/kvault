#!/usr/bin/env bash
# ralph-batch.sh — supervised batch loop for well-specified tasks.
# One task per invocation, fresh Claude context each pass, stops on DONE
# or after N iterations. Tasks come from docs/tasks/queue.md.
#
# Usage:
#   ./scripts/ralph-batch.sh --once        # single pass (test it first)
#   ./scripts/ralph-batch.sh -n 10         # up to 10 tasks
#   ./scripts/ralph-batch.sh --dry-run     # show the next task, run nothing
#
# Safety: works on branches only, never main. Each pass must pass
# typecheck + tests to count as done. Review every PR before merging.
set -uo pipefail

QUEUE="docs/tasks/queue.md"
MAX=10
ONCE=false
DRY_RUN=false

while [ $# -gt 0 ]; do
  case "$1" in
    -n) MAX="$2"; shift 2 ;;
    --once) ONCE=true; MAX=1; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

if [ ! -f "$QUEUE" ]; then
  echo "No queue found at $QUEUE. Copy docs/tasks/TEMPLATE.md, fill it in, and list tasks in queue.md."
  exit 1
fi

# Next task = first unchecked "- [ ]" line in the queue.
next_task() {
  grep -m 1 "^- \[ \]" "$QUEUE" || true
}

for i in $(seq 1 "$MAX"); do
  TASK_LINE=$(next_task)
  if [ -z "$TASK_LINE" ]; then
    echo "DONE: queue is empty."
    exit 0
  fi
  echo "== Pass $i/$MAX: $TASK_LINE =="
  if [ "$DRY_RUN" = true ]; then
    echo "(dry run — stopping here)"
    exit 0
  fi
  if ! command -v claude >/dev/null 2>&1; then
    echo "claude CLI not found. Install Claude Code first."
    exit 1
  fi
  # One task per invocation. The agent reads the spec, implements it on a
  # branch, runs typecheck + tests + /verify, and marks the queue item done
  # ONLY if verification passes. It must stop after this one task.
  PROMPT="You are working from the batch queue in this repo. Do exactly ONE task, then stop.

Task line from docs/tasks/queue.md:
$TASK_LINE

Read the full spec for this task (docs/tasks/ or the linked issue). Follow AGENTS.md and /implement-tdd: branch, failing test first, minimal implementation, run typecheck + lint + tests + build. Do NOT push to main. Do NOT start a second task.

If verification passes: commit on the branch, mark this exact queue line as done (- [x]) in docs/tasks/queue.md, and print DONE on its own line. If verification fails: leave the queue line unchecked, commit your work-in-progress on the branch, print BLOCKED plus the reason, and stop."
  echo "$PROMPT" | claude -p --permission-mode plan 2>&1 | tee "/tmp/ralph-pass-$i.log"
  # Note: run with default permissions once you trust the loop; --permission-mode plan
  # is the safe starting point. For unattended runs, prefer a sandbox (see README Phase B).
  if [ "$ONCE" = true ]; then
    echo "Single pass complete. Check the branch + /tmp/ralph-pass-$i.log before continuing."
    exit 0
  fi
done

echo "Reached max passes ($MAX). Review branches before running again."
