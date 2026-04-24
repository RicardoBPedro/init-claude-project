#!/usr/bin/env bash
# hook-prepush-validate.sh — Claude Code PreToolUse hook wrapper for `git push`.
# Emits hookSpecificOutput JSON on stdout (allow by default; deny on protected
# branch or when check-secrets fails).
#
# Invoked from .claude/settings.json — not for standalone use.

set -u

# Pick a working python (Windows Store stub handling).
if python3 --version >/dev/null 2>&1; then
  PY=python3
elif python --version >/dev/null 2>&1; then
  PY=python
else
  # No python available — can't emit structured JSON. Let husky handle it.
  exit 0
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
branch=$(git -C "$ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

[ -z "$branch" ] && exit 0

# Protected branches: standard convention + user-chosen main/staging (substituted
# at install time by copy::substitute). Empty placeholders are safely skipped.
PROTECTED='main master homolog staging develop {{MAIN_BRANCH}} {{STAGING_BRANCH}}'

for p in $PROTECTED; do
  [ -z "$p" ] && continue
  if [ "$branch" = "$p" ]; then
    ICP_BRANCH="$branch" "$PY" -c "$(cat <<'PY'
import json, os
b = os.environ["ICP_BRANCH"]
reason = "Cannot push directly to " + repr(b) + ". Protected branch — use a PR or pipeline."
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": reason,
    }
}))
PY
)"
    exit 0
  fi
done

# Not protected — run secret scan. Wrap in `(cd "$ROOT" && ...)` because
# check-secrets.sh invokes git without `-C`, and Claude Code hooks may run
# from a working directory that isn't the project root.
if ! ( cd "$ROOT" && bash scripts/check-secrets.sh ) >/dev/null 2>&1; then
  "$PY" -c "$(cat <<'PY'
import json
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": "Secrets detected in staged changes. Review scripts/check-secrets.sh output before pushing.",
    }
}))
PY
)"
  exit 0
fi

# Default: allow (silent).
exit 0
