#!/usr/bin/env bash
# init-upgrade.sh — refresh init-claude-project assets in an EXISTING project.
# Mirrors init-frontend.sh / init-backend.sh structure, but sets ICP_MODE=upgrade
# so each copy::* function performs a per-file merge instead of a fresh write.
# Usage: ./init-upgrade.sh <target-dir>

set -euo pipefail

__ICP_ENTRY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/ui.sh
source "$__ICP_ENTRY_DIR/lib/ui.sh"
# shellcheck source=lib/preflight.sh
source "$__ICP_ENTRY_DIR/lib/preflight.sh"
# shellcheck source=lib/copy.sh
source "$__ICP_ENTRY_DIR/lib/copy.sh"

# All copy::* functions consult this. Set BEFORE any of them run.
export ICP_MODE=upgrade

# Target defaults to "." (current dir) — handy when running from the project
# root in an IDE-integrated terminal.
target="${1:-.}"
[ -d "$target" ] || { ui::error "Target does not exist: $target"; exit 1; }

ui::section "init-claude-project — upgrade"
ui::info "Target: $target"

# --- Detect project type (replaces the install-time --type arg) ---
# Priority: STACK env (from install.sh) > build-file detection > prompt.
# STACK lets us recover the type for `base`-installed projects (Python/Go/Rust/etc)
# that have no build.gradle/pom.xml/package.json.
type=""
if [ -n "${STACK:-}" ]; then
  type=$(copy::stack_to_type "$STACK")
fi
[ -z "$type" ] && type=$(copy::detect_type "$target")
# If still unknown but the project has toolkit markers, default to base — the
# project was likely installed with --type=base originally.
if [ -z "$type" ] && [ -f "$target/.husky/naming.conf" ]; then
  type="base"
  ui::info "No build files found, but toolkit markers present — assuming type=base."
fi
if [ -z "$type" ]; then
  ui::warn "Could not auto-detect project type."
  type=$(ui::ask "Project type [frontend|backend|base]" "base")
fi
case "$type" in
  frontend|backend|base) ui::info "Detected type: $type" ;;
  *) ui::error "Invalid type: $type"; exit 1 ;;
esac

# --- Preflight: tools + globals ---
preflight::run "$type" || ui::warn "Preflight had warnings — continuing in upgrade mode."

# --- Pre-copy conflict check is a no-op in upgrade mode ---
copy::check_conflicts "$target" || exit 1

# --- Recover settings from existing files; only ask when undetectable ---
ui::section "Project settings"

# CLAUDE.md is preserved untouched in upgrade mode — PROJECT_SUMMARY only feeds
# substitution if md_sources are rewritten, which won't happen if it exists.
PROJECT_SUMMARY="(preserved from existing CLAUDE.md)"
[ -f "$target/CLAUDE.md" ] || {
  PROJECT_SUMMARY=$(ui::ask "One-line project summary (no CLAUDE.md found, will be created)")
}

MAIN_BRANCH=$(copy::detect_main_branch "$target")
ui::info "Main branch (detected from .husky/pre-push): $MAIN_BRANCH"

STAGING_BRANCH=""
if [ -f "$target/.husky/pre-push" ] && grep -q "homolog\|staging" "$target/.husky/pre-push" 2>/dev/null; then
  STAGING_BRANCH=$(grep -E "^PROTECTED=" "$target/.husky/pre-push" | head -1 \
    | sed -E "s/^PROTECTED='([^']*)'.*/\1/" | awk '{print $7}')
fi

# Optional addendums + naming gates: only asked when the relevant artifact is
# absent (otherwise existing user state wins — upgrades shouldn't undo choices).
WITH_BRAZIL=0
WITH_MUTATION=0
ENFORCE_COMMIT_MSG=1
ENFORCE_BRANCH_NAME=1

export PROJECT_SUMMARY MAIN_BRANCH STAGING_BRANCH WITH_BRAZIL WITH_MUTATION ENFORCE_COMMIT_MSG ENFORCE_BRANCH_NAME

# --- Confirm plan ---
ui::section "Upgrade plan"
cat <<EOF
  Target directory:       $target
  Detected type:          $type
  Main branch (detected): $MAIN_BRANCH
  Staging branch:         ${STAGING_BRANCH:-<none>}

  In upgrade mode each copy::* call:
    - adds files the project doesn't have yet (no prompt),
    - shows [overwrite/skip/diff] for managed files that already differ,
    - keeps user-customizable files untouched (CLAUDE.md, naming.conf, verify.sh,
      memory seeds with same name).
  .claude/settings.json gets a JSON merge: template-managed hook entries are
  refreshed in place, user-defined hooks for any event are preserved.
EOF
ui::confirm "Proceed with upgrade?" 1 || { ui::warn "Aborted by user."; exit 0; }

# --- Run upgrade — same call sequence as init-{frontend,backend}.sh ---
ui::section "Refreshing files"
copy::md_sources       "$type" "$target"
copy::scripts          "$type" "$target"
copy::husky            "$type" "$target"
copy::claude_settings  "$type" "$target"
copy::root_files                "$target"
copy::gitignore                 "$target"
copy::memory_seeds              "$target"

# --- Next steps ---
ui::section "Done"
cat <<EOF
Upgrade complete.

Review:
  - *.orig backup files in scripts/ and .husky/        (managed files you overwrote)
  - .husky/naming.conf                                  (your conventions — unchanged)
  - scripts/verify.sh                                   (your quality gate — unchanged unless newly added)
  - .claude/settings.json                               (template hooks refreshed; user hooks preserved)

If CLAUDE.md was kept untouched, diff it against the toolkit sources to pick up
new sections (e.g. 'Quality gate (auto-verify on Stop)'):
  - md_sources/CLAUDE/base.md           (always merged)
  - md_sources/CLAUDE/stack-${STACK:-<stack-id>}.md  (the stack addendum for your project)
EOF
