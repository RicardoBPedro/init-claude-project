#!/usr/bin/env bash
# init-frontend.sh — bootstrap a new frontend project (React + Vite + Vitest).
# Usage: ./init-frontend.sh <target-dir>

set -euo pipefail

__ICP_ENTRY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/ui.sh
source "$__ICP_ENTRY_DIR/lib/ui.sh"
# shellcheck source=lib/preflight.sh
source "$__ICP_ENTRY_DIR/lib/preflight.sh"
# shellcheck source=lib/copy.sh
source "$__ICP_ENTRY_DIR/lib/copy.sh"

target="${1:-}"
if [ -z "$target" ]; then
  ui::error "Missing target directory."
  echo "Usage: $0 <target-dir>" >&2
  exit 1
fi

ui::section "init-claude-project — frontend"
ui::info "Target: $target"

# --- Preflight ---
preflight::run frontend || exit 1

# --- Gather interactive inputs (minimal — the rest are baked defaults) ---
ui::section "Project settings"
PROJECT_SUMMARY=$(ui::ask "One-line project summary (e.g. 'Internal billing dashboard.')")
MAIN_BRANCH=$(ui::ask "Main branch name" "main")

STAGING_BRANCH=""
if ui::confirm "Does this project have a staging/homolog branch?"; then
  STAGING_BRANCH=$(ui::ask "Staging branch name" "staging")
fi

export PROJECT_SUMMARY MAIN_BRANCH STAGING_BRANCH

# --- Confirm plan ---
ui::section "Installation plan"
cat <<EOF
  Target directory:       $target
  Project type:           frontend
  Main branch:            $MAIN_BRANCH
  Staging branch:         ${STAGING_BRANCH:-<none>}
  Will create / update:
    - $target/CLAUDE.md                      (base + frontend addendum)
    - $target/docs/troubleshooting.md
    - $target/scripts/*                       (branch-hygiene.sh, check-secrets.sh, branch-start.sh)
    - $target/.husky/*                        (commit-msg, pre-commit, pre-push)
    - $target/.claude/settings.json           (SessionStart + pre-push hooks)
    - $target/.gitignore                      (append Claude-related entries)
    - ~/.claude/projects/<hashed>/memory/*.md  (7 universal memory seeds)
EOF
ui::confirm "Proceed with installation?" 1 || { ui::warn "Aborted by user."; exit 0; }

# --- Install ---
mkdir -p "$target"

ui::section "Writing files"
copy::md_sources       frontend "$target"
copy::scripts          frontend "$target"
copy::husky            frontend "$target"
copy::claude_settings  frontend "$target"
copy::root_files                "$target"
copy::gitignore                 "$target"
copy::memory_seeds              "$target"

# --- Next steps ---
ui::section "Done"
cat <<EOF
Next steps:

  cd $target
  git init -b $MAIN_BRANCH                          # if not already a repo
  npm install                                       # install frontend deps (when package.json exists)
  npx husky install                                 # activate git hooks
  git add .
  git commit -m "chore: bootstrap Claude Code workflow"

Review before first commit:
  - CLAUDE.md                                       (validate project summary, branch names)
  - .claude/settings.json                           (hook paths use absolute root — verify)
  - docs/troubleshooting.md                         (delete sections that don't apply to your host OS)

Read:
  - CLAUDE.md > Working principles + Gitflow
  - docs/troubleshooting.md > Environment section
EOF
