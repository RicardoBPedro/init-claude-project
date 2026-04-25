#!/usr/bin/env bash
# hook-stop-verify.sh — Claude Code Stop hook wrapper.
#
# Runs scripts/verify.sh when there are uncommitted code changes; blocks Claude
# from declaring "done" if checks fail (decision=block, with the failure
# output as the reason — Claude reads it and keeps working).
#
# Skip conditions (silent exit 0):
#   - not in a git repo
#   - .claude/verify.disabled exists (user opt-out)
#   - working tree clean vs HEAD (nothing changed → nothing to gate)
#   - scripts/verify.sh missing
#
# Invoked from .claude/settings.json — not for standalone use.

set -u

if python3 --version >/dev/null 2>&1; then
  PY=python3
elif python --version >/dev/null 2>&1; then
  PY=python
else
  exit 0
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
[ -f "$ROOT/.claude/verify.disabled" ] && exit 0
[ -f "$ROOT/scripts/verify.sh" ] || exit 0

# Skip if working tree is fully clean — nothing to gate. `git status --porcelain`
# covers tracked changes (staged + unstaged) AND untracked files; plain `git diff
# HEAD` misses untracked, which would let new files (common in feature work) slip
# past the gate.
if [ -z "$(git -C "$ROOT" status --porcelain 2>/dev/null)" ]; then
  exit 0
fi

# Run verify; capture output so we can ship it back to Claude on failure.
output=$(cd "$ROOT" && bash scripts/verify.sh 2>&1)
rc=$?

if [ "$rc" -eq 0 ]; then
  exit 0
fi

# Failed → block + return the output. Claude will see this and keep working
# until the next Stop, when verify.sh runs again. Truncate huge outputs so the
# hook payload stays under typical size limits.
ICP_OUT="$output" "$PY" -c "$(cat <<'PY'
import json, os
out = os.environ.get("ICP_OUT", "")
if len(out) > 4000:
    out = out[:2000] + "\n...[truncated]...\n" + out[-2000:]
print(json.dumps({
    "decision": "block",
    "reason": "Quality gate (scripts/verify.sh) failed. Fix the failures before declaring the task done.\n\n" + out,
}))
PY
)"
exit 0
