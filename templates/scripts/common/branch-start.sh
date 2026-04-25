#!/usr/bin/env bash
# branch-start.sh — create a new branch from an up-to-date main.
#
# Enforces the local workflow rule: every new branch starts from fresh main.
# Refuses to proceed if:
#   - working tree is dirty
#   - main is behind its upstream AND can't fast-forward
#   - branch name doesn't match the project's BRANCH_NAME_REGEX (.husky/naming.conf)
#
# Usage:
#   scripts/branch-start.sh <branch-name>
#
# Naming convention is project-specific — see .husky/naming.conf.
#
# Env:
#   MAIN_BRANCH=main    override integration branch (default: main)

set -euo pipefail

MAIN_BRANCH="${MAIN_BRANCH:-main}"

new_branch="${1:-}"
if [ -z "$new_branch" ]; then
  echo "Usage: $0 <branch-name>" >&2
  echo "  See .husky/naming.conf for this project's branch naming convention." >&2
  exit 1
fi

# Load project-specific naming convention (optional).
BRANCH_NAME_REGEX=""
BRANCH_NAME_FORMAT=""
BRANCH_NAME_EXAMPLE=""
repo_root=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
if [ -f "$repo_root/.husky/naming.conf" ]; then
  # shellcheck disable=SC1091
  . "$repo_root/.husky/naming.conf"
fi

if [ -n "$BRANCH_NAME_REGEX" ] && ! echo "$new_branch" | grep -qE "$BRANCH_NAME_REGEX"; then
  echo "ERROR: '$new_branch' doesn't match this project's branch naming convention." >&2
  [ -n "$BRANCH_NAME_FORMAT" ]  && echo "  Format:  $BRANCH_NAME_FORMAT" >&2
  [ -n "$BRANCH_NAME_EXAMPLE" ] && echo "  Example: $BRANCH_NAME_EXAMPLE" >&2
  echo "  Regex:   $BRANCH_NAME_REGEX" >&2
  echo "  Edit .husky/naming.conf to adjust or disable the rule." >&2
  exit 1
fi

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
