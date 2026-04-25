#!/usr/bin/env bash
# init-base.sh — install ONLY the universal toolkit (no frontend/backend addendum).
#
# Used when the project's stack isn't covered by the React/Vue/Angular/Svelte
# frontend templates or the Java backend templates — e.g. Python, Go, Rust,
# .NET, Ruby, Flutter, Node backend, anything else. The user gets:
#   - CLAUDE.md = base.md only (universal principles, gitflow, testing standards)
#   - branch hygiene + naming.conf + commit/branch convention enforcers
#   - quality gate skeleton (scripts/verify.sh — empty, ready to fill in)
#   - SessionStart + PreToolUse + Stop hooks
#   - memory seeds
# but NOT:
#   - stack-specific CLAUDE.md addendum
#   - lint-staged / spotless pre-commit (no stack to lint)
#
# Mirrors init-frontend.sh / init-backend.sh structure. Usage: ./init-base.sh <target-dir>

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

ui::section "init-claude-project — base (no stack-specific templates)"
ui::info "Target: $target"

# --- Preflight: tools + globals ---
# type=base only requires the universal tools (git, jq, python3) — no node, no jdk.
# The jq query in preflight::run filters to required:true items when no type-specific
# tools match, so passing "base" Just Works even without a "base" entry in the manifest.
preflight::run base || exit 1

# --- Pre-copy: abort if any target file we'd write already exists ---
mkdir -p "$target"
copy::check_conflicts "$target" || exit 1

# --- Gather interactive inputs ---
ui::section "Project settings"
PROJECT_SUMMARY=$(ui::ask "One-line project summary (e.g. 'Internal data pipeline.')")
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

# Mutation testing addendum is stack-specific (PITest for Java, Stryker for JS),
# so it's intentionally skipped in base mode.
WITH_MUTATION=0

ENFORCE_COMMIT_MSG=1
ui::confirm "Enforce commit message convention? (default '[<TYPE>]#<task>: ...')" 1 || ENFORCE_COMMIT_MSG=0

ENFORCE_BRANCH_NAME=1
ui::confirm "Enforce branch naming convention? (default '<type>/<card>/<slug>')" 1 || ENFORCE_BRANCH_NAME=0

export PROJECT_SUMMARY MAIN_BRANCH STAGING_BRANCH WITH_BRAZIL WITH_MUTATION ENFORCE_COMMIT_MSG ENFORCE_BRANCH_NAME

# --- Confirm plan ---
ui::section "Installation plan"
cat <<EOF
  Target directory:       $target
  Project type:           base (universal only — no stack-specific addendum)
  Main branch:            $MAIN_BRANCH
  Staging branch:         ${STAGING_BRANCH:-<none>}
  Brazil addendum:        $([ "$WITH_BRAZIL" = "1" ] && echo yes || echo no)
  Commit-msg check:       $([ "$ENFORCE_COMMIT_MSG" = "1" ] && echo enabled || echo disabled)
  Branch-name check:      $([ "$ENFORCE_BRANCH_NAME" = "1" ] && echo enabled || echo disabled)
  Will create:
    - $target/CLAUDE.md                      (base.md $([ -n "${STACK:-}" ] && echo "+ stack-${STACK}.md addendum" || echo "only — no stack-specific addendum"))
    - $target/docs/troubleshooting.md
    - $target/scripts/*.sh                    (branch-hygiene, branch-start, check-secrets, check-todo-budget, seed-memory, verify, hook-prepush-validate, hook-sessionstart, hook-stop-verify)
    - $target/.husky/{commit-msg,pre-push,naming.conf}
                                              NOTE: no pre-commit (stack-specific). Add lint hooks yourself.
    - $target/.claude/settings.json           (SessionStart + pre-push + Stop hooks)
    - $target/.claude/memory-seeds/*.md       (7 universal seeds)
    - $target/.gitattributes
    - $target/.gitignore                      (append Claude-related entries)

  After install, you'll likely want to:
    - Edit CLAUDE.md and append a section with your stack's commands and testing idioms.
    - Edit scripts/verify.sh to add your lint/typecheck/test invocations
      (toolkit's verify.sh detects only Java/Maven/Gradle and Node — silent for others).
    - Add a .husky/pre-commit if you want lint-on-commit.
EOF
ui::confirm "Proceed with installation?" 1 || { ui::warn "Aborted by user."; exit 0; }

# --- Install — same call sequence as init-{frontend,backend}.sh, but type=base
#     means copy::* skips the per-stack subdirs (no templates/scripts/base/, no
#     templates/husky/base/) and copy::md_sources writes only base.md ---
ui::section "Writing files"
copy::md_sources       base "$target"
copy::scripts          base "$target"
copy::husky            base "$target"
copy::claude_settings  base "$target"
copy::root_files            "$target"
copy::gitignore             "$target"
copy::memory_seeds          "$target"

# --- Next steps ---
ui::section "Done"

if [ -e "$target/.git" ]; then
  hooks_step="# Hooks already wired (core.hooksPath=.husky configured above)"
else
  hooks_step="git init -b $MAIN_BRANCH && git config core.hooksPath .husky"
fi

cat <<EOF
Next steps:

  cd $target
  $hooks_step
  git add .
  git commit -m "[CHORE]#0: bootstrap Claude Code workflow (base)"

After your first Claude Code session in this project, run ONCE to seed memories:

  bash scripts/seed-memory.sh

Customize for your stack:
  - CLAUDE.md                     append a "## Commands" section + "## Test layer hierarchy" tuned to your toolchain
  - scripts/verify.sh             add the lint/typecheck/test commands your CI uses
  - .husky/naming.conf            adjust commit/branch regex if your team uses different conventions
  - .husky/pre-commit             create one if you want pre-commit lint (templates ship none for base mode)

Read first:
  - CLAUDE.md > Working principles + Gitflow + Quality gate
  - docs/troubleshooting.md
EOF
