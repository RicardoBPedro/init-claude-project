#!/usr/bin/env bash
# seed-memory.sh — copy memory seeds into Claude Code's real memory dir.
#
# Run ONCE after your first Claude Code session in this project (so Claude
# has created the target dir). Safe to re-run — existing files are not
# overwritten.
#
# Claude Code stores project memory at:
#   ~/.claude/projects/<hashed-absolute-project-path>/memory/
#
# where <hashed> is the OS-native absolute path with every non-alphanumeric
# character replaced by '-' and the drive letter (if any) lowercased.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SEEDS_DIR="$ROOT/.claude/memory-seeds"

[ -d "$SEEDS_DIR" ] || {
  echo "ERROR: $SEEDS_DIR not found." >&2
  echo "       This script expects to run inside a project bootstrapped by init-claude-project." >&2
  exit 1
}

# Pick python interpreter (handle Windows Store stub that claims python3 but exits non-zero).
if python3 --version >/dev/null 2>&1; then PY=python3
elif python --version >/dev/null 2>&1; then PY=python
else
  echo "ERROR: python not found (need python3 or python in PATH)." >&2
  exit 1
fi

# Resolve native absolute path (backslash form on Windows to match Claude Code's hashing).
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*)
    if command -v cygpath >/dev/null 2>&1; then
      abs=$(cygpath -w "$ROOT")
    else
      abs=$(cd "$ROOT" && pwd -W 2>/dev/null || pwd)
    fi
    ;;
  *)
    abs="$ROOT"
    ;;
esac

# Compute Claude's hashed dir name: lowercase drive letter (Windows), each
# non-alphanumeric char → '-', strip edge dashes.
hashed=$(ICP_ABS="$abs" "$PY" -c '
import os, re
p = os.environ["ICP_ABS"].strip()
if len(p) >= 2 and p[1] == ":":
    p = p[0].lower() + p[1:]
print(re.sub(r"[^A-Za-z0-9]", "-", p).strip("-"))
')

MEM_DIR="$HOME/.claude/projects/$hashed/memory"

echo "Project native path: $abs"
echo "Computed hash:       $hashed"
echo "Target memory dir:   $MEM_DIR"
echo ""

if [ ! -d "$MEM_DIR" ]; then
  echo "WARN: $MEM_DIR doesn't exist yet."
  echo ""
  echo "      Claude Code creates this directory on first session in a project."
  echo "      Open Claude Code in this project, let it load once, then re-run this script."
  echo ""
  echo "      (If you're certain the hash is correct, create manually:"
  echo "         mkdir -p \"$MEM_DIR\""
  echo "       and re-run.)"
  exit 1
fi

copied=0
skipped=0
for f in "$SEEDS_DIR"/*.md; do
  name=$(basename "$f")
  [ "$name" = "README.md" ] && continue

  if [ "$name" = "MEMORY.md" ]; then
    # Never overwrite an existing MEMORY.md index. Write beside as a seed
    # for manual merge — the index drifts per project.
    if [ -f "$MEM_DIR/MEMORY.md" ]; then
      cp "$f" "$MEM_DIR/MEMORY.md.seed"
      echo "  ~ MEMORY.md exists — seed written to MEMORY.md.seed (manual merge needed)"
      skipped=$((skipped+1))
      continue
    fi
  elif [ -e "$MEM_DIR/$name" ]; then
    echo "  skip $name (already exists)"
    skipped=$((skipped+1))
    continue
  fi

  cp "$f" "$MEM_DIR/$name"
  echo "  + $name"
  copied=$((copied+1))
done

echo ""
echo "Copied:  $copied"
echo "Skipped: $skipped"
echo ""
echo "Done. Start a new Claude Code session to load the seeded memories."
