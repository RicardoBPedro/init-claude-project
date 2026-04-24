#!/usr/bin/env bash
# test-backend.sh — run backend tests with Docker context normalized.
#
# Wraps ./gradlew test so that:
#   - Windows hosts run under DOCKER_CONTEXT=desktop-linux (avoids the Named Pipe
#     hang with Testcontainers' Ryuk — see docs/troubleshooting.md).
#   - The right wrapper (gradlew.bat vs ./gradlew) is picked automatically.
#
# Usage:
#   scripts/test-backend.sh                        # full suite
#   scripts/test-backend.sh --tests "FQCN"         # single class
#   scripts/test-backend.sh clean test             # arbitrary gradle args

set -euo pipefail

# Detect OS and Docker context fix
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*)
    # Windows under Git Bash — scope the context switch so the user's global default stays untouched.
    if command -v docker >/dev/null 2>&1 && docker context inspect desktop-linux >/dev/null 2>&1; then
      export DOCKER_CONTEXT=desktop-linux
    fi
    WRAPPER="./gradlew.bat"
    ;;
  *)
    WRAPPER="./gradlew"
    ;;
esac

# Find repo root (with gradlew)
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [ ! -f "$WRAPPER" ] && [ -f "./gradlew" ]; then
  WRAPPER="./gradlew"
fi
if [ ! -f "$WRAPPER" ]; then
  echo "ERROR: no gradlew wrapper found at $ROOT" >&2
  exit 1
fi

# Default task = test; otherwise pass args through.
if [ $# -eq 0 ]; then
  exec "$WRAPPER" test
else
  exec "$WRAPPER" test "$@"
fi
