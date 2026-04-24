#!/usr/bin/env bash
# hook-sessionstart.sh — Claude Code SessionStart hook wrapper.
# Runs branch-hygiene.sh and surfaces findings as additionalContext for Claude.
#
# Invoked from .claude/settings.json — not for standalone use.

set -u

if python3 --version >/dev/null 2>&1; then
  PY=python3
elif python --version >/dev/null 2>&1; then
  PY=python
else
  exit 0  # No python → stay silent (better than broken output).
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Capture output + exit code without letting errexit kill us.
# Wrap in `(cd "$ROOT" && ...)` because branch-hygiene.sh invokes git without
# `-C`, and Claude Code hooks may run from a working directory that isn't the
# project root.
set +e
out=$( cd "$ROOT" && bash scripts/branch-hygiene.sh 2>&1 )
code=$?
set -e 2>/dev/null || true

if [ "$code" -ne 0 ]; then
  ICP_OUT="$out" "$PY" -c "$(cat <<'PY'
import json, os
out = os.environ["ICP_OUT"]
ctx = "=== BRANCH HYGIENE ALERT ===\n" + out + "\n\nResolve stale branches BEFORE starting new work. See CLAUDE.md > Gitflow > Branch hygiene."
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": ctx,
    }
}))
PY
)"
elif echo "$out" | grep -qE 'OLD FORK POINT|FORKED FROM NON-MAIN'; then
  ICP_OUT="$out" "$PY" -c "$(cat <<'PY'
import json, os
out = os.environ["ICP_OUT"]
ctx = "=== BRANCH HYGIENE WARNING ===\n" + out + "\n\nReview flagged branches. Not a blocker for new work, but worth resolving soon."
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": ctx,
    }
}))
PY
)"
fi

exit 0
