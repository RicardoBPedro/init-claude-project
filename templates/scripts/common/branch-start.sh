#!/usr/bin/env bash
# branch-start.sh — create a new branch from an up-to-date main.
#
# Enforces the local workflow rule: every new branch starts from fresh main.
# Refuses to proceed if:
#   - working tree is dirty
#   - main is behind its upstream AND can't fast-forward
#
# Usage:
#   scripts/branch-start.sh feat/short-description
#   scripts/branch-start.sh fix/bug-123
#
# Env:
#   MAIN_BRANCH=main    override integration branch (default: main)

set -euo pipefail

MAIN_BRANCH="${MAIN_BRANCH:-main}"

new_branch="${1:-}"
if [ -z "$new_branch" ]; then
  echo "Usage: $0 <type>/<short-description>" >&2
  echo "  type = feat | fix | refactor | chore | test | docs | perf | style" >&2
  exit 1
fi

case "$new_branch" in
  feat/*|fix/*|refactor/*|chore/*|test/*|docs/*|perf/*|style/*) : ;;
  *)
    echo "ERROR: branch name must start with feat/, fix/, refactor/, chore/, test/, docs/, perf/, or style/" >&2
    exit 1
    ;;
esac

# 1. Working tree clean?
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "ERROR: working tree is dirty. Commit or stash before creating a new branch." >&2
  git status --short >&2
  exit 1
fi

# 2. Fall back to master if main doesn't exist
if ! git show-ref --verify --quiet "refs/heads/$MAIN_BRANCH"; then
  if git show-ref --verify --quiet "refs/heads/master"; then
    echo "Note: '$MAIN_BRANCH' not found, falling back to 'master'."
    MAIN_BRANCH="master"
  else
    echo "ERROR: neither '$MAIN_BRANCH' nor 'master' exists locally." >&2
    exit 1
  fi
fi

# 3. Fetch + update main
echo "Fetching origin..."
git fetch origin

echo "Updating $MAIN_BRANCH..."
git checkout "$MAIN_BRANCH"
if ! git pull --ff-only; then
  echo "ERROR: $MAIN_BRANCH is not fast-forwardable from origin/$MAIN_BRANCH." >&2
  echo "       Rebase or reset manually, then re-run." >&2
  exit 1
fi

# 4. Create branch
echo "Creating branch: $new_branch"
git checkout -b "$new_branch"
echo "Done. You're on $new_branch (based on latest $MAIN_BRANCH)."
