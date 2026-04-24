#!/usr/bin/env bash
# copy.sh — file operations: conflict detection, template copy, placeholder
# substitution, project-local memory seeding. Sourced by init-frontend.sh /
# init-backend.sh. Don't run directly.

set -euo pipefail

__ICP_COPY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__ICP_COPY_ROOT="$(cd "$__ICP_COPY_DIR/.." && pwd)"

# shellcheck source=./ui.sh
source "$__ICP_COPY_DIR/ui.sh"

# copy::check_conflicts <target_dir>
# Aborts if any file the installer would overwrite already exists. Runs BEFORE
# prompts / copy, so the user fails fast and doesn't waste time answering.
copy::check_conflicts() {
  local target="$1"
  local conflicts=()

  # Files written directly
  [ -f "$target/CLAUDE.md" ]                 && conflicts+=("CLAUDE.md")
  [ -f "$target/docs/troubleshooting.md" ]   && conflicts+=("docs/troubleshooting.md")
  [ -f "$target/.claude/settings.json" ]     && conflicts+=(".claude/settings.json")

  # Scripts we install by name
  local s
  for s in branch-hygiene.sh branch-start.sh check-secrets.sh check-todo-budget.sh seed-memory.sh test-backend.sh; do
    [ -f "$target/scripts/$s" ] && conflicts+=("scripts/$s")
  done

  # Husky hooks
  local h
  for h in commit-msg pre-push pre-commit; do
    [ -f "$target/.husky/$h" ] && conflicts+=(".husky/$h")
  done

  if [ ${#conflicts[@]} -gt 0 ]; then
    ui::error "Target directory already contains files this installer would overwrite:"
    local f
    for f in "${conflicts[@]}"; do
      printf '  - %s/%s\n' "$target" "$f" >&2
    done
    echo "" >&2
    ui::dim "  To proceed: back up / remove the conflicting files, or choose a fresh target directory." >&2
    ui::dim "  This installer deliberately refuses to overwrite existing config to protect your work." >&2
    return 1
  fi
  return 0
}

# copy::substitute <file> [strip_meta]
# Replaces placeholders in-place using env vars:
#   PROJECT_SUMMARY, MAIN_BRANCH, STAGING_BRANCH, PROJECT_ROOT.
# If strip_meta=1, also strips template bookkeeping: HTML comments in markdown
# and "_comment" fields in JSON (so the installed file is clean).
copy::substitute() {
  local file="$1"
  local strip_meta="${2:-0}"
  [ -f "$file" ] || return 0
  PYICP_FILE="$file" PYICP_STRIP="$strip_meta" "$(ui::python)" - <<'PY'
import os, re, json
path = os.environ["PYICP_FILE"]
strip = os.environ.get("PYICP_STRIP") == "1"
subs = {
    "{{PROJECT_SUMMARY}}": os.environ.get("PROJECT_SUMMARY", ""),
    "{{MAIN_BRANCH}}":     os.environ.get("MAIN_BRANCH", "main"),
    "{{STAGING_BRANCH}}":  os.environ.get("STAGING_BRANCH", ""),
    "__PROJECT_ROOT__":    os.environ.get("PROJECT_ROOT", ""),
}
with open(path, "r", encoding="utf-8") as f:
    content = f.read()

if strip:
    # Strip HTML comments (<!-- ... -->) — template bookkeeping.
    content = re.sub(r"<!--.*?-->\s*", "", content, flags=re.DOTALL)
    # For JSON files, drop top-level `_comment` keys.
    if path.endswith(".json") or path.endswith(".tmpl"):
        try:
            data = json.loads(content)
            if isinstance(data, dict):
                def clean(obj):
                    if isinstance(obj, dict):
                        return {k: clean(v) for k, v in obj.items() if k != "_comment"}
                    if isinstance(obj, list):
                        return [clean(x) for x in obj]
                    return obj
                data = clean(data)
                content = json.dumps(data, indent=2, ensure_ascii=False) + "\n"
        except json.JSONDecodeError:
            pass  # Not valid JSON yet (has placeholders) — fall through.

for k, v in subs.items():
    content = content.replace(k, v)

with open(path, "w", encoding="utf-8") as f:
    f.write(content)
PY
}

# copy::md_sources <type:frontend|backend> <target_dir>
# Reads WITH_BRAZIL env var (0/1) to decide whether to append the Brazil addendum.
copy::md_sources() {
  local type="$1"
  local target="$2"
  local src="$__ICP_COPY_ROOT/md_sources"
  local with_brazil="${WITH_BRAZIL:-0}"

  ui::info "Writing CLAUDE.md"
  mkdir -p "$target"
  {
    cat "$src/CLAUDE/base.md"
    printf '\n\n---\n\n'
    cat "$src/CLAUDE/$type.md"
    if [ "$with_brazil" = "1" ] && [ -f "$src/CLAUDE/brazil.md" ]; then
      printf '\n\n---\n\n'
      cat "$src/CLAUDE/brazil.md"
    fi
  } > "$target/CLAUDE.md"
  copy::substitute "$target/CLAUDE.md" 1

  ui::info "Writing docs/troubleshooting.md"
  mkdir -p "$target/docs"
  cp "$src/docs/troubleshooting.md" "$target/docs/troubleshooting.md"
  copy::substitute "$target/docs/troubleshooting.md" 1
}

# copy::memory_seeds <target_dir>
# Writes universal memory seeds into $target/.claude/memory-seeds/. Claude
# Code's actual memory dir is ~/.claude/projects/<hashed-path>/memory/, which
# Claude creates lazily on first session. scripts/seed-memory.sh (installed
# separately) handles the final copy with correct cross-platform hashing.
#
# This indirection avoids the risk of writing to a wrong hashed directory if
# the OS-specific hashing assumption is off — seeds are safely placed in a
# deterministic project-local path first.
copy::memory_seeds() {
  local target="$1"
  local src="$__ICP_COPY_ROOT/md_sources/memory-seeds"
  local dest="$target/.claude/memory-seeds"

  ui::info "Writing memory seeds to .claude/memory-seeds/"
  mkdir -p "$dest"
  local f name
  for f in "$src"/*.md; do
    name=$(basename "$f")
    cp "$f" "$dest/$name"
  done

  # Drop a README explaining purpose + activation step.
  cat > "$dest/README.md" <<'EOF'
# Memory seeds

Universal Claude Code memories (feedback + references) bundled with this project by `init-claude-project`.

Claude Code stores project memory at `~/.claude/projects/<hashed-project-path>/memory/`. The dir is created lazily on the first Claude session in this project.

## Activation

After running `claude` at least once in this project (so Claude creates the memory dir), run:

```bash
bash scripts/seed-memory.sh
```

That script computes the hashed path correctly for your OS and copies each file under this folder into Claude's real memory dir, skipping files that already exist.

## What's in here

- `feedback_*.md` — 6 universal feedback memories (branch hygiene, coverage ratchet, Opus for audits, docs-with-code, Claude config authorization, global vs project skills)
- `reference_testing_standard.md` — testing discipline summary (6 principles + zero-tolerance)
- `MEMORY.md` — index that gets prepended to the project's MEMORY.md

Review these before activating. Edit freely — they're yours.
EOF
}

# copy::scripts <type> <target_dir>
copy::scripts() {
  local type="$1"
  local target="$2"
  local src="$__ICP_COPY_ROOT/templates/scripts"

  mkdir -p "$target/scripts"
  ui::info "Installing scripts/"
  if [ -d "$src/common" ]; then
    cp -R "$src/common/." "$target/scripts/"
  fi
  if [ -d "$src/$type" ]; then
    cp -R "$src/$type/." "$target/scripts/"
  fi
  find "$target/scripts" -type f -name '*.sh' -exec chmod +x {} + 2>/dev/null || true
}

# copy::husky <type> <target_dir>
copy::husky() {
  local type="$1"
  local target="$2"
  local src="$__ICP_COPY_ROOT/templates/husky"

  mkdir -p "$target/.husky"
  ui::info "Installing .husky/ (native git hooks, no npm dependency)"
  if [ -d "$src/common" ]; then
    cp -R "$src/common/." "$target/.husky/"
  fi
  if [ -d "$src/$type" ]; then
    cp -R "$src/$type/." "$target/.husky/"
  fi
  find "$target/.husky" -type f ! -name '*.md' -exec chmod +x {} + 2>/dev/null || true

  # If target is already a git repo, wire hooksPath immediately — otherwise
  # the post-install instructions explain how to do it after git init.
  if git -C "$target" rev-parse --git-dir >/dev/null 2>&1; then
    git -C "$target" config core.hooksPath .husky
    ui::ok "Configured core.hooksPath=.husky in the existing git repo"
  fi
}

# copy::claude_settings <type> <target_dir>
copy::claude_settings() {
  local type="$1"
  local target="$2"
  local src="$__ICP_COPY_ROOT/templates/claude"

  mkdir -p "$target/.claude"
  ui::info "Installing .claude/settings.json"
  local tmpl="$src/settings.json.tmpl"
  [ -f "$src/$type/settings.json.tmpl" ] && tmpl="$src/$type/settings.json.tmpl"
  cp "$tmpl" "$target/.claude/settings.json"

  export PROJECT_ROOT
  PROJECT_ROOT="$(ui::abs_path "$target")"
  copy::substitute "$target/.claude/settings.json" 1
}

# copy::root_files <target_dir>
# Copies files that live at target root (currently just .gitattributes).
# Skips existing files — doesn't overwrite user's own root config.
copy::root_files() {
  local target="$1"
  local src="$__ICP_COPY_ROOT/templates/root"
  [ -d "$src" ] || return 0
  ui::info "Installing root config files"
  local f name
  for f in "$src"/* "$src"/.[!.]*; do
    [ -e "$f" ] || continue
    name=$(basename "$f")
    if [ -e "$target/$name" ]; then
      ui::dim "  skip $name (already exists)"
      continue
    fi
    cp "$f" "$target/$name"
    ui::dim "  + $name"
  done
}

# copy::gitignore <target_dir>
# Appends Claude-related entries to .gitignore if missing.
copy::gitignore() {
  local target="$1"
  local gi="$target/.gitignore"
  [ -f "$gi" ] || : > "$gi"
  if grep -qE '^docs/scrum/' "$gi" 2>/dev/null; then
    ui::dim ".gitignore already references docs/scrum/ — skipped"
    return 0
  fi
  cat >> "$gi" <<'EOF'

# Claude Code / init-claude-project
.claude/settings.local.json
.remember/
docs/scrum/
EOF
  ui::ok "Appended Claude-related entries to .gitignore"
}
