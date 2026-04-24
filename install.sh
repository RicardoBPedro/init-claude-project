#!/usr/bin/env bash
# install.sh — one-liner bootstrap + local dispatcher.
#
# Usage (remote, via curl):
#   bash <(curl -fsSL https://raw.githubusercontent.com/<user>/init-claude-project/main/install.sh) frontend ./my-new-project
#   bash <(curl -fsSL https://raw.githubusercontent.com/<user>/init-claude-project/main/install.sh) backend  ./my-new-project
#
# Usage (local, from a clone):
#   ./install.sh frontend ./my-new-project
#   ./install.sh backend  ./my-new-project

set -euo pipefail

REPO_URL="${ICP_REPO_URL:-https://github.com/RicardoBPedro/init-claude-project.git}"
REPO_REF="${ICP_REPO_REF:-main}"
ICP_HOME="${ICP_HOME:-$HOME/.init-claude-project}"

type="${1:-}"
target="${2:-}"

usage() {
  cat <<'EOF'
init-claude-project — bootstrap a new project with Claude Code conventions.

Usage:
  install.sh <frontend|backend> <target-directory>

Example:
  install.sh frontend ./my-new-app
  install.sh backend  ./my-new-api

Environment:
  ICP_REPO_URL   override the git URL (default: github.com/RicardoBPedro/init-claude-project)
  ICP_REPO_REF   pin to a branch or tag (default: main — use 'vX.Y.Z' for release pinning)
  ICP_HOME       clone location for the toolkit (default: ~/.init-claude-project)
EOF
}

if [ -z "$type" ] || [ -z "$target" ]; then
  usage
  exit 1
fi

case "$type" in
  frontend|backend) : ;;
  -h|--help) usage; exit 0 ;;
  *) echo "Unknown type: $type" >&2; usage; exit 1 ;;
esac

# Detect whether we're running from a local checkout or a remote curl | bash pipe.
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd -P 2>/dev/null || true)"

# Heuristic for "am I running from a checked-out repo?": check for lib/preflight.sh
# relative to this script's dir.
if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/lib/preflight.sh" ]; then
  # Local mode — dispatch directly.
  exec "$SCRIPT_DIR/init-${type}.sh" "$target"
fi

# Remote mode — clone (or update) the toolkit to $ICP_HOME, then exec from there.
echo "[i] Bootstrapping init-claude-project toolkit to $ICP_HOME"

if ! command -v git >/dev/null 2>&1; then
  echo "[x] git is required to bootstrap. Install from https://git-scm.com/downloads" >&2
  exit 1
fi

if [ -d "$ICP_HOME/.git" ]; then
  echo "[i] Updating existing checkout at $ICP_HOME (ref: $REPO_REF)"
  # Warn if there are uncommitted changes — `reset --hard` will destroy them.
  if ! git -C "$ICP_HOME" diff --quiet HEAD 2>/dev/null || ! git -C "$ICP_HOME" diff --cached --quiet HEAD 2>/dev/null; then
    echo ""
    echo "[!] $ICP_HOME has uncommitted local changes. Updating will discard them."
    echo "    Press Ctrl-C within 5 seconds to abort."
    echo ""
    sleep 5
  fi
  git -C "$ICP_HOME" fetch --quiet origin "$REPO_REF"
  git -C "$ICP_HOME" reset --hard --quiet FETCH_HEAD
else
  echo "[i] Cloning $REPO_URL (ref: $REPO_REF)"
  git clone --depth 1 --branch "$REPO_REF" --quiet "$REPO_URL" "$ICP_HOME"
fi

exec "$ICP_HOME/init-${type}.sh" "$target"
