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

# Target defaults to "." (current dir) — handy when running from the project
# root in an IDE-integrated terminal.
target="${1:-.}"

ui::section "init-claude-project — frontend"
ui::info "Target: $target"

# --- Preflight: tools + globals ---
preflight::run frontend || exit 1

# --- Pre-copy: abort if any target file we'd write already exists ---
mkdir -p "$target"
copy::check_conflicts "$target" || exit 1

# --- Gather interactive inputs ---
ui::section "Project settings"
PROJECT_SUMMARY=$(ui::ask "One-line project summary (e.g. 'Internal billing dashboard.')")
while [ -z "$PROJECT_SUMMARY" ]; do
  ui::warn "Project summary can't be empty — it anchors the project's CLAUDE.md."
  PROJECT_SUMMARY=$(ui::ask "One-line project summary")
done
MAIN_BRANCH=$(ui::ask "Main branch name" "main")
while ! ui::valid_branch_name "$MAIN_BRANCH"; do
  ui::warn "Invalid branch name: '$MAIN_BRANCH'. Must follow git rules (no whitespace, glob chars, etc)."
  MAIN_BRANCH=$(ui::ask "Main branch name" "main")
done

STAGING_BRANCH=""
if ui::confirm "Does this project have a staging/homolog branch?"; then
  STAGING_BRANCH=$(ui::ask "Staging branch name" "staging")
  while ! ui::valid_branch_name "$STAGING_BRANCH"; do
    ui::warn "Invalid branch name: '$STAGING_BRANCH'. Must follow git rules (no whitespace, glob chars, etc)."
    STAGING_BRANCH=$(ui::ask "Staging branch name" "staging")
  done
fi

WITH_BRAZIL=0
if ui::confirm "Include Brazil legal context addendum (LGPD, Marco Civil, CDC)?"; then
  WITH_BRAZIL=1
fi

WITH_MUTATION=0
if ui::confirm "Include mutation testing guidance (Stryker)? Only useful if you'll actually run it on critical paths — otherwise skip to keep CLAUDE.md lean"; then
  WITH_MUTATION=1
fi

# Naming conventions are project-specific and editable in .husky/naming.conf
# post-install. Default ON; opt out per-check here. Defaults match the format
# documented in CLAUDE.md > Commit Convention / Gitflow.
ENFORCE_COMMIT_MSG=1
ui::confirm "Enforce commit message convention? (default '[<TYPE>]#<task>: ...')" 1 || ENFORCE_COMMIT_MSG=0

ENFORCE_BRANCH_NAME=1
ui::confirm "Enforce branch naming convention? (default '<type>/<card>/<slug>')" 1 || ENFORCE_BRANCH_NAME=0

export PROJECT_SUMMARY MAIN_BRANCH STAGING_BRANCH WITH_BRAZIL WITH_MUTATION ENFORCE_COMMIT_MSG ENFORCE_BRANCH_NAME

# --- Confirm plan ---
ui::section "Installation plan"
cat <<EOF
  Target directory:       $target
  Project type:           frontend
  Main branch:            $MAIN_BRANCH
  Staging branch:         ${STAGING_BRANCH:-<none>}
  Brazil addendum:        $([ "$WITH_BRAZIL" = "1" ] && echo yes || echo no)
  Mutation addendum:      $([ "$WITH_MUTATION" = "1" ] && echo yes || echo no)
  Commit-msg check:       $([ "$ENFORCE_COMMIT_MSG" = "1" ] && echo enabled || echo disabled)
  Branch-name check:      $([ "$ENFORCE_BRANCH_NAME" = "1" ] && echo enabled || echo disabled)
  Will create:
    - $target/CLAUDE.md                      (base + frontend addendum)
    - $target/docs/troubleshooting.md
    - $target/scripts/*.sh                    (branch-hygiene, branch-start, check-secrets, check-todo-budget, seed-memory, verify, hook-stop-verify)
    - $target/.husky/{commit-msg,pre-push,pre-commit,naming.conf}
    - $target/.claude/settings.json           (SessionStart + pre-push hooks)
    - $target/.claude/memory-seeds/*.md       (7 universal seeds — activate via scripts/seed-memory.sh post-install)
    - $target/.gitattributes                  (pin LF for .sh / .husky)
    - $target/.gitignore                      (append Claude-related entries)
EOF
ui::confirm "Proceed with installation?" 1 || { ui::warn "Aborted by user."; exit 0; }

# --- Install ---
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

if [ -e "$target/.git" ]; then
  # Target is the ROOT of a git repo — copy::husky already wired core.hooksPath.
  hooks_step="# Hooks already wired (core.hooksPath=.husky configured above)"
else
  hooks_step="git init -b $MAIN_BRANCH && git config core.hooksPath .husky"
fi

cat <<EOF
Next steps:

  cd $target
  $hooks_step
  # Install frontend deps (if package.json exists / after npm init):
  npm install
  git add .
  git commit -m "[CHORE]#0: bootstrap Claude Code workflow (frontend)"

After your first Claude Code session in this project (Claude creates its
memory dir lazily), run this ONCE to seed the universal memories:

  bash scripts/seed-memory.sh

Review before your first commit:
  - CLAUDE.md                                       validate the project summary + branch names
  - .claude/settings.json                           hook paths use your absolute project root
  - .claude/memory-seeds/                           universal memories — edit before seeding if you like
  - docs/troubleshooting.md                         drop sections that don't apply to your host OS

Read first:
  - CLAUDE.md > Working principles + Gitflow (local-only workflow)
  - docs/troubleshooting.md > Environment section
EOF
