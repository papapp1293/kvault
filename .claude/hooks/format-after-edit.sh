#!/usr/bin/env bash
# PostToolUse hook: format the edited file so CI doesn't fail on style.
# Reads the Claude Code event JSON from stdin, extracts file_path, runs
# rustfmt for .rs files and prettier for web files when available.
# Always exits 0 (formatting must never block the edit itself).
set -uo pipefail

INPUT=$(cat)
FILE=$(echo "$INPUT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('tool_input',{}).get('file_path',''))" 2>/dev/null || echo "")

if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
  exit 0
fi

case "$FILE" in
  *.rs)
    if command -v rustfmt >/dev/null 2>&1; then
      rustfmt --edition 2021 "$FILE" 2>/dev/null || true
    fi
    ;;
  *.ts|*.tsx|*.js|*.jsx|*.json|*.md|*.css|*.html)
    if command -v npx >/dev/null 2>&1 && [ -f "$CLAUDE_PROJECT_DIR/package.json" ]; then
      (cd "$CLAUDE_PROJECT_DIR" && npx --no-install prettier --write "$FILE" 2>/dev/null) || true
    fi
    ;;
esac

exit 0
