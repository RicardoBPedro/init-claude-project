#!/usr/bin/env bash
# copy.sh — file operations: copy templates, substitute placeholders, seed memory.
# Sourced by init-frontend.sh / init-backend.sh. Don't run directly.

set -euo pipefail

__ICP_COPY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__ICP_COPY_ROOT="$(cd "$__ICP_COPY_DIR/.." && pwd)"

# shellcheck source=./ui.sh
source "$__ICP_COPY_DIR/ui.sh"

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
    # Strip HTML comments (<!-- ... -->) — used in md_sources for template bookkeeping.
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
            pass  # Not valid JSON yet (has placeholders) — fall through to plain replace.

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
# Claude Code memory path is ~/.claude/projects/<hashed-project-path>/memory/
# where hashed replaces every non-alphanumeric char with "-", collapsing runs.
copy::memory_seeds() {
  local target="$1"
  local abs
  abs=$(ui::abs_path "$target")

  local hashed
  hashed=$(ICP_ABS="$abs" "$(ui::python)" -c '
import os, re
p = os.environ["ICP_ABS"].strip()
# Lowercase a leading drive letter (Windows form: C:\Users → c:\Users).
if len(p) >= 2 and p[1] == ":":
    p = p[0].lower() + p[1:]
# Replace runs of non-alphanumeric with "-", strip edge dashes.
hashed = re.sub(r"[^A-Za-z0-9]+", "-", p).strip("-")
print(hashed)
')
  local mem_dir="$HOME/.claude/projects/$hashed/memory"
  ui::info "Seeding memory at $mem_dir"
  mkdir -p "$mem_dir"

  local src="$__ICP_COPY_ROOT/md_sources/memory-seeds"
  local f name
  for f in "$src"/*.md; do
    name=$(basename "$f")
    # MEMORY.md (index) is handled separately below — skip here.
    [ "$name" = "MEMORY.md" ] && continue
    if [ -e "$mem_dir/$name" ]; then
      ui::dim "  skip $name (already exists)"
      continue
    fi
    cp "$f" "$mem_dir/$name"
    ui::dim "  + $name"
  done

  # MEMORY.md: create if missing, otherwise write as MEMORY.md.seed for manual merge.
  local idx_src="$src/MEMORY.md"
  if [ -f "$mem_dir/MEMORY.md" ]; then
    cp "$idx_src" "$mem_dir/MEMORY.md.seed"
    ui::warn "memory/MEMORY.md exists — seed written to MEMORY.md.seed for manual merge"
  else
    cp "$idx_src" "$mem_dir/MEMORY.md"
    ui::dim "  + MEMORY.md"
  fi
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
  ui::info "Installing .husky/"
  if [ -d "$src/common" ]; then
    cp -R "$src/common/." "$target/.husky/"
  fi
  if [ -d "$src/$type" ]; then
    cp -R "$src/$type/." "$target/.husky/"
  fi
  find "$target/.husky" -type f ! -name '*.md' -exec chmod +x {} + 2>/dev/null || true
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
copy::root_files() {
  local target="$1"
  local src="$__ICP_COPY_ROOT/templates/root"
  [ -d "$src" ] || return 0
  ui::info "Installing root config files"
  local f name
  # Iterate visible + dotfiles separately — bash globs don't mix them cleanly.
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
