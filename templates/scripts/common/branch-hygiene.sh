#!/usr/bin/env bash
# branch-hygiene.sh — detect stale / forgotten / improperly-forked local branches.
#
# STRICTLY LOCAL: no `git fetch`, no forge API calls, no inspection of origin/*
# refs. Works offline and never waits on the network. All checks use local
# refs under refs/heads/ only.
#
# For each non-protected local branch, the script evaluates:
#   1. Fully merged into <main>? → healthy (safe to delete). Reported, not flagged.
#   2. Age > STALE_DAYS AND not merged? → STALE UNMERGED. Flagged (exit 1).
#   3. Merge-base with <main> older than STALE_BASE_DAYS? → OLD FORK POINT. Reported warn.
#   4. Branch appears to have been forked from develop (or another non-main branch)?
#      → FORKED FROM NON-MAIN. Reported warn. Violates the "branch from main" rule.
#   5. Otherwise → active.
#
# Env overrides:
#   MAIN_BRANCH=main       override the integration branch name
#   STALE_DAYS=14          age threshold for flagging unmerged branches (default covers a 2-week sprint)
#   STALE_BASE_DAYS=30     warn if merge-base with main is older than this
#
# Usage:
#   bash scripts/branch-hygiene.sh           # human-readable report
#   bash scripts/branch-hygiene.sh --quiet   # print only when flagged
#   bash scripts/branch-hygiene.sh --json    # machine-readable
#
# Exit codes:
#   0 — no stale unmerged branches (warnings still reported)
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
STALE_DAYS="${STALE_DAYS:-14}"
STALE_BASE_DAYS="${STALE_BASE_DAYS:-30}"

PROTECTED_RE='^(master|main|homolog|staging|develop)$'

STALE_UNMERGED=()
STALE_BASE=()
FORKED_FROM_NONMAIN=()
HEALTHY_MERGED=()
ACTIVE=()

# Local branches only — never list remote-tracking refs.
# Portable alternative to `mapfile -t` (bash 4+; macOS ships bash 3.2).
BRANCHES=()
while IFS= read -r line; do
  [ -n "$line" ] && BRANCHES+=("$line")
done < <(git for-each-ref --format='%(refname:short)' refs/heads/)

# Verify the main branch ref exists locally; fall back to master if not.
if ! git show-ref --verify --quiet "refs/heads/$MAIN_BRANCH"; then
  if git show-ref --verify --quiet "refs/heads/master"; then
    MAIN_BRANCH="master"
  fi
fi
MAIN_REF="refs/heads/$MAIN_BRANCH"

# Does a local develop exist? Only used for the "forked from non-main" heuristic.
DEVELOP_EXISTS=0
if git show-ref --verify --quiet "refs/heads/develop"; then
  DEVELOP_EXISTS=1
fi

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

  # Merge-base age with main.
  mb_main=$(git merge-base "$br" "$MAIN_REF" 2>/dev/null || echo "")
  mb_main_age=0
  if [ -n "$mb_main" ]; then
    mb_main_ts=$(git log -1 --format=%ct "$mb_main" 2>/dev/null || echo "$now_ts")
    mb_main_age=$(( (now_ts - mb_main_ts) / 86400 ))
  fi

  # "Forked from non-main" heuristic. If a local develop exists and the branch's
  # merge-base with develop is strictly ahead of its merge-base with main (i.e.,
  # mb_main is an ancestor of mb_dev, and they differ), the branch was most
  # likely forked from develop rather than main.
  forked_nonmain=0
  if [ "$DEVELOP_EXISTS" = "1" ] && [ "$merged" = "0" ]; then
    mb_dev=$(git merge-base "$br" refs/heads/develop 2>/dev/null || echo "")
    if [ -n "$mb_dev" ] && [ -n "$mb_main" ] && [ "$mb_dev" != "$mb_main" ]; then
      if git merge-base --is-ancestor "$mb_main" "$mb_dev" 2>/dev/null; then
        forked_nonmain=1
      fi
    fi
  fi

  if [ "$merged" = "1" ]; then
    HEALTHY_MERGED+=("$br|$age_days")
    continue
  fi

  if [ "$age_days" -gt "$STALE_DAYS" ]; then
    STALE_UNMERGED+=("$br|$age_days|$mb_main_age|$forked_nonmain")
  else
    ACTIVE+=("$br|$age_days|$mb_main_age|$forked_nonmain")
    if [ "$mb_main_age" -gt "$STALE_BASE_DAYS" ]; then
      STALE_BASE+=("$br|$age_days|$mb_main_age")
    fi
  fi

  if [ "$forked_nonmain" = "1" ]; then
    FORKED_FROM_NONMAIN+=("$br|$age_days|$mb_main_age")
  fi
done

if [ "$JSON" = "1" ]; then
  printf '{"stale_unmerged":['
  sep=""
  for o in "${STALE_UNMERGED[@]}"; do
    IFS='|' read -r n a mb fn <<< "$o"
    printf '%s{"branch":"%s","age_days":%s,"merge_base_age_days":%s,"forked_from_nonmain":%s}' "$sep" "$n" "$a" "$mb" "$fn"
    sep=","
  done
  printf '],"stale_base":['
  sep=""
  for o in "${STALE_BASE[@]}"; do
    IFS='|' read -r n a mb <<< "$o"
    printf '%s{"branch":"%s","age_days":%s,"merge_base_age_days":%s}' "$sep" "$n" "$a" "$mb"
    sep=","
  done
  printf '],"forked_from_nonmain":['
  sep=""
  for o in "${FORKED_FROM_NONMAIN[@]}"; do
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
    IFS='|' read -r n a mb fn <<< "$o"
    printf '%s{"branch":"%s","age_days":%s,"merge_base_age_days":%s,"forked_from_nonmain":%s}' "$sep" "$n" "$a" "$mb" "$fn"
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
    IFS='|' read -r n a mb fn <<< "$o"
    flag=""
    [ "$fn" = "1" ] && flag="  [forked from non-main]"
    printf '  - %-40s  age=%sd  fork=%sd%s\n' "$n" "$a" "$mb" "$flag"
  done
  echo ""
  echo "Options per branch:"
  echo "  (a) git checkout <branch> && git rebase $MAIN_BRANCH   # bring up to date, continue work"
  echo "  (b) push to remote + open PR manually                  # if ready for review"
  echo "  (c) git branch -D <branch>                             # abandon (only after inspecting diff!)"
  echo ""
  exit 1
fi

if [ "${#FORKED_FROM_NONMAIN[@]}" -gt 0 ]; then
  echo ""
  echo "=========================================="
  echo "BRANCHES FORKED FROM NON-MAIN (${#FORKED_FROM_NONMAIN[@]})"
  echo "=========================================="
  echo "Active branches whose merge-base suggests they were created from 'develop'"
  echo "(or another branch) instead of '$MAIN_BRANCH'. Violates the 'branch from main' rule."
  echo "Rebase onto $MAIN_BRANCH to realign: git checkout <branch> && git rebase $MAIN_BRANCH."
  echo ""
  for o in "${FORKED_FROM_NONMAIN[@]}"; do
    IFS='|' read -r n a mb <<< "$o"
    printf '  - %-40s  age=%sd  fork=%sd\n' "$n" "$a" "$mb"
  done
  echo ""
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
  echo "Branch hygiene: OK (local-only — no fetch, no forge calls)"
  echo "  Active: ${#ACTIVE[@]}"
  for o in "${ACTIVE[@]}"; do
    IFS='|' read -r n a mb fn <<< "$o"
    flag=""
    [ "$fn" = "1" ] && flag="  [forked from non-main]"
    printf '    - %-40s  age=%sd  fork=%sd%s\n' "$n" "$a" "$mb" "$flag"
  done
  echo "  Merged (safe to delete): ${#HEALTHY_MERGED[@]}"
  for o in "${HEALTHY_MERGED[@]}"; do
    IFS='|' read -r n a <<< "$o"
    printf '    - %-40s  age=%sd\n' "$n" "$a"
  done
fi

exit 0
