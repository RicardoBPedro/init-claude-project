#!/usr/bin/env bash
# branch-hygiene.sh — detect stale / forgotten local branches.
#
# Local-only: does NOT query GitHub/GitLab/any forge. Works for any git host.
#
# For each non-protected local branch:
#   1. Fully merged into <main> → healthy (can be deleted). Reported, not flagged.
#   2. Not merged AND last commit older than STALE_DAYS → STALE. Flagged (exit 1).
#   3. Everything else → active. Reported with age + divergence.
#
# Env overrides:
#   MAIN_BRANCH=main       override the integration branch name
#   STALE_DAYS=7           age threshold for flagging unmerged branches
#   STALE_BASE_DAYS=30     warn if the merge-base with main is older than this
#
# Usage:
#   bash scripts/branch-hygiene.sh           # human-readable report
#   bash scripts/branch-hygiene.sh --quiet   # print only when flagged
#   bash scripts/branch-hygiene.sh --json    # machine-readable
#
# Exit codes:
#   0 — no stale unmerged branches
#   1 — one or more stale unmerged branches detected

set -eo pipefail

MODE="${1:-}"
QUIET=0
JSON=0
case "$MODE" in
  --quiet) QUIET=1 ;;
  --json)  JSON=1 ;;
esac

MAIN_BRANCH="${MAIN_BRANCH:-main}"
STALE_DAYS="${STALE_DAYS:-7}"
STALE_BASE_DAYS="${STALE_BASE_DAYS:-30}"

PROTECTED_RE='^(master|main|homolog|staging|develop)$'

STALE_UNMERGED=()
STALE_BASE=()
HEALTHY_MERGED=()
ACTIVE=()

# Refresh remote state (non-fatal if offline)
git fetch --all --prune --quiet 2>/dev/null || true

# Enumerate local branches only (no remote listing — we stay strictly local).
mapfile -t BRANCHES < <(git for-each-ref --format='%(refname:short)' refs/heads/)

# Verify the main branch ref exists; fall back to master if not.
if ! git show-ref --verify --quiet "refs/heads/$MAIN_BRANCH"; then
  if git show-ref --verify --quiet "refs/heads/master"; then
    MAIN_BRANCH="master"
  fi
fi
MAIN_REF="refs/heads/$MAIN_BRANCH"

now_ts=$(date +%s)

for br in "${BRANCHES[@]}"; do
  [[ "$br" =~ $PROTECTED_RE ]] && continue
  [ "$br" = "$MAIN_BRANCH" ] && continue

  last_ts=$(git log -1 --format=%ct "$br" 2>/dev/null || echo 0)
  age_days=$(( (now_ts - last_ts) / 86400 ))

  # Is the branch fully merged into main?
  merged=0
  if git merge-base --is-ancestor "$br" "$MAIN_REF" 2>/dev/null; then
    merged=1
  fi

  # Merge-base age (how old is the fork point vs main)
  mb=$(git merge-base "$br" "$MAIN_REF" 2>/dev/null || echo "")
  mb_age_days=0
  if [ -n "$mb" ]; then
    mb_ts=$(git log -1 --format=%ct "$mb" 2>/dev/null || echo "$now_ts")
    mb_age_days=$(( (now_ts - mb_ts) / 86400 ))
  fi

  if [ "$merged" = "1" ]; then
    HEALTHY_MERGED+=("$br|$age_days")
  elif [ "$age_days" -gt "$STALE_DAYS" ]; then
    STALE_UNMERGED+=("$br|$age_days|$mb_age_days")
  else
    ACTIVE+=("$br|$age_days|$mb_age_days")
    if [ "$mb_age_days" -gt "$STALE_BASE_DAYS" ]; then
      STALE_BASE+=("$br|$age_days|$mb_age_days")
    fi
  fi
done

if [ "$JSON" = "1" ]; then
  printf '{"stale_unmerged":['
  sep=""
  for o in "${STALE_UNMERGED[@]}"; do
    IFS='|' read -r n a mb <<< "$o"
    printf '%s{"branch":"%s","age_days":%s,"merge_base_age_days":%s}' "$sep" "$n" "$a" "$mb"
    sep=","
  done
  printf '],"stale_base":['
  sep=""
  for o in "${STALE_BASE[@]}"; do
    IFS='|' read -r n a mb <<< "$o"
    printf '%s{"branch":"%s","age_days":%s,"merge_base_age_days":%s}' "$sep" "$n" "$a" "$mb"
    sep=","
  done
  printf '],"merged":['
  sep=""
  for o in "${HEALTHY_MERGED[@]}"; do
    IFS='|' read -r n a <<< "$o"
    printf '%s{"branch":"%s","age_days":%s}' "$sep" "$n" "$a"
    sep=","
  done
  printf '],"active":['
  sep=""
  for o in "${ACTIVE[@]}"; do
    IFS='|' read -r n a mb <<< "$o"
    printf '%s{"branch":"%s","age_days":%s,"merge_base_age_days":%s}' "$sep" "$n" "$a" "$mb"
    sep=","
  done
  printf ']}\n'
  [ "${#STALE_UNMERGED[@]}" -gt 0 ] && exit 1
  exit 0
fi

if [ "${#STALE_UNMERGED[@]}" -gt 0 ]; then
  echo ""
  echo "=========================================="
  echo "STALE UNMERGED BRANCHES (${#STALE_UNMERGED[@]})"
  echo "=========================================="
  echo "Branches with unmerged commits AND no activity in $STALE_DAYS+ days."
  echo "Resolve before starting new work — lost work is the worst failure mode."
  echo ""
  for o in "${STALE_UNMERGED[@]}"; do
    IFS='|' read -r n a mb <<< "$o"
    printf '  - %-40s  age=%sd  fork=%sd\n' "$n" "$a" "$mb"
  done
  echo ""
  echo "Options per branch:"
  echo "  (a) git checkout <branch> && git rebase $MAIN_BRANCH   # bring up to date, continue work"
  echo "  (b) push to remote + open PR manually                  # if ready for review"
  echo "  (c) git branch -D <branch>                             # abandon (only after inspecting diff!)"
  echo ""
  exit 1
fi

if [ "${#STALE_BASE[@]}" -gt 0 ]; then
  echo ""
  echo "=========================================="
  echo "BRANCHES WITH OLD FORK POINT (${#STALE_BASE[@]})"
  echo "=========================================="
  echo "Active branches whose merge-base with $MAIN_BRANCH is >$STALE_BASE_DAYS days old."
  echo "Rebase onto latest $MAIN_BRANCH before pushing — diffs against the target will be cleaner."
  echo ""
  for o in "${STALE_BASE[@]}"; do
    IFS='|' read -r n a mb <<< "$o"
    printf '  - %-40s  age=%sd  fork=%sd\n' "$n" "$a" "$mb"
  done
  echo ""
fi

if [ "$QUIET" = "0" ]; then
  echo "Branch hygiene: OK"
  echo "  Active: ${#ACTIVE[@]}"
  for o in "${ACTIVE[@]}"; do
    IFS='|' read -r n a mb <<< "$o"
    printf '    - %-40s  age=%sd  fork=%sd\n' "$n" "$a" "$mb"
  done
  echo "  Merged (safe to delete): ${#HEALTHY_MERGED[@]}"
  for o in "${HEALTHY_MERGED[@]}"; do
    IFS='|' read -r n a <<< "$o"
    printf '    - %-40s  age=%sd\n' "$n" "$a"
  done
fi

exit 0
