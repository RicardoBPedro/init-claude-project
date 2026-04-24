#!/usr/bin/env bash
# check-secrets.sh — scan files about to be pushed for potential secrets.
# Exit 1 if secrets found, 0 if clean.
#
# Called from .husky/pre-push and from Claude Code's PreToolUse hook on git push.

set -u

SECRETS_FOUND=0

# Files about to be pushed (diff against upstream, excluding deletions).
REMOTE=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || echo "origin/$(git rev-parse --abbrev-ref HEAD)")
FILES=$(git diff --name-only --diff-filter=d "$REMOTE"...HEAD 2>/dev/null || git diff --name-only --diff-filter=d HEAD~1 2>/dev/null || echo "")

[ -z "$FILES" ] && exit 0

# Patterns to search inside file contents.
PATTERNS=(
  'password\s*[:=]'
  'secret\s*[:=]'
  'api[_-]?key\s*[:=]'
  'private[_-]?key\s*[:=]'
  'eyJ[A-Za-z0-9_-]{10,}\.'
  'AKIA[0-9A-Z]{16}'
)

# Filenames that are always flagged regardless of content.
DANGEROUS_FILES=(
  '\.env$'
  '\.env\.local$'
  '\.env\.production$'
  '\.env\.staging$'
  'credentials\.json$'
  '\.pem$'
  '\.key$'
  'id_rsa'
  'id_ed25519'
)

# Files to skip (false-positive hot-spots).
SKIP_PATTERNS='\.lock$|\.md$|CLAUDE\.md$|\.test\.|\.spec\.|node_modules|\.git/|\.cache/|dist/|build/'

# YAML config files that need special scanning (ignore ${ENV_VAR} refs).
YAML_PATTERNS='application\.ya?ml$|application-.*\.ya?ml$|config/.*\.ya?ml$'

for file in $FILES; do
  [ ! -f "$file" ] && continue
  echo "$file" | grep -qE "$SKIP_PATTERNS" && continue

  for pattern in "${DANGEROUS_FILES[@]}"; do
    if echo "$file" | grep -qE "$pattern"; then
      echo "BLOCKED: dangerous file: $file"
      SECRETS_FOUND=1
    fi
  done

  if echo "$file" | grep -qE "$YAML_PATTERNS"; then
    # YAML: ignore lines with ${...} env var refs or empty values
    for pattern in "${PATTERNS[@]}"; do
      matches=$(grep -nE "$pattern" "$file" 2>/dev/null | grep -vF '${' | grep -vE ':\s*$' || true)
      if [ -n "$matches" ]; then
        line=$(echo "$matches" | head -1)
        echo "BLOCKED: potential hardcoded secret in $file: $line"
        SECRETS_FOUND=1
      fi
    done
  else
    for pattern in "${PATTERNS[@]}"; do
      if grep -qE "$pattern" "$file" 2>/dev/null; then
        line=$(grep -nE "$pattern" "$file" | head -1)
        echo "BLOCKED: potential secret in $file: $line"
        SECRETS_FOUND=1
      fi
    done
  fi
done

if [ "$SECRETS_FOUND" -eq 1 ]; then
  echo ""
  echo "Push blocked: potential secrets detected."
  echo "If these are false positives, review and add exceptions to scripts/check-secrets.sh"
  exit 1
fi

exit 0
