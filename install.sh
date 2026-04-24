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
  echo "[i] Updating existing checkout"
  git -C "$ICP_HOME" fetch --quiet origin
  git -C "$ICP_HOME" reset --hard --quiet origin/main
else
  echo "[i] Cloning $REPO_URL"
  git clone --depth 1 --quiet "$REPO_URL" "$ICP_HOME"
fi

exec "$ICP_HOME/init-${type}.sh" "$target"
