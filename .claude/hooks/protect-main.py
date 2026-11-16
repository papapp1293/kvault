#!/usr/bin/env python3
"""PreToolUse hook: block edits under protected paths.

Reads the Claude Code event JSON from stdin. Exit 2 blocks the action;
exit 0 allows it. Blocks: migrations/ hand-edits, .env files, lockfile
hand-edits. The git push-to-main block lives in settings.json permissions.
"""
import json
import sys

BLOCKED_SUBSTRINGS = (
    "/migrations/",
    "migrations/",
    ".env",
    ".pem",
    "package-lock.json",
    "pnpm-lock.yaml",
    "yarn.lock",
)


def main():
    try:
        event = json.load(sys.stdin)
    except Exception:
        return 0
    tool_input = event.get("tool_input", {}) or {}
    path = tool_input.get("file_path", "") or ""
    for blocked in BLOCKED_SUBSTRINGS:
        if blocked in path:
            print(f"Blocked: {path} matches protected pattern '{blocked}'. "
                  "Use the owning tool (prisma migrate / package manager) instead of hand-editing.",
                  file=sys.stderr)
            return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
