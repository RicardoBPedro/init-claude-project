#!/usr/bin/env bash
# check-todo-budget.sh — flag TODO/FIXME comments added in staged changes
# that lack a ticket reference (e.g. [US-123], [JIRA-456], [GH-789]).
#
# Only scans lines being ADDED in the staged diff — existing un-IDed TODOs
# in the codebase are not flagged (they pre-exist this rule).
#
# Usage:
#   bash scripts/check-todo-budget.sh
#
# Exit codes:
#   0 — no un-IDed TODO/FIXME added
#   1 — at least one un-IDed TODO/FIXME in staged changes
#
# See CLAUDE.md > TODO budget.

set -u

# Added lines (prefix '+'), excluding the '+++' diff header.
added=$(git diff --cached -U0 2>/dev/null | grep -E '^\+' | grep -vE '^\+\+\+' || true)
[ -z "$added" ] && exit 0

# Lines containing TODO or FIXME (case-insensitive) that do NOT contain a
# bracketed ticket reference like [US-123], [JIRA-456], [GH-789].
offenders=$(printf '%s\n' "$added" \
  | grep -iE '(TODO|FIXME)' \
  | grep -ivE '(TODO|FIXME)[[:space:]]*\[[A-Z]+-[0-9]+\]' \
  || true)

if [ -n "$offenders" ]; then
  echo ""
  echo "ERROR: TODO / FIXME without ticket reference in staged changes:"
  echo ""
  printf '%s\n' "$offenders" | sed 's/^+/  /'
  echo ""
  echo "Rule: every new TODO / FIXME must reference a ticket — e.g. // TODO [US-NNN]: ..."
  echo "See CLAUDE.md > TODO budget."
  echo ""
  echo "Fix: attach a ticket ID, or remove the TODO before committing."
  echo ""
  exit 1
fi

exit 0
