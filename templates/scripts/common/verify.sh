#!/usr/bin/env bash
# verify.sh — local quality gate. Runs the checks that should pass before
# declaring an implementation done.
#
# Used by:
#   - Manual:  bash scripts/verify.sh
#   - Hook:    .claude/settings.json Stop hook (via hook-stop-verify.sh)
#   - CI:      same script, ensures local-CI parity
#
# Customize freely — add/remove steps to match what your project actually needs.
# To DISABLE the auto-gate (Stop hook) without touching this script, create an
# empty file at .claude/verify.disabled.
#
# Exit code:
#   0 → all configured checks passed (or no recognized stack — silent skip)
#   1 → one or more checks failed (Claude will be told to keep working)

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

fail=0
ran_any=0

run_step() {
  local name="$1"; shift
  ran_any=1
  printf '\n>> %s\n' "$name"
  if ! "$@"; then
    printf '   ↳ FAILED (%s)\n' "$name" >&2
    fail=1
  fi
}

# --- Backend: Gradle ---
if [ -f build.gradle ] || [ -f build.gradle.kts ]; then
  if grep -qE '(spotless|ktlint|googleJavaFormat)' build.gradle* 2>/dev/null; then
    run_step "spotless (gradle)" ./gradlew --quiet spotlessCheck
  fi
  # Compile only — running the full test suite on every Stop is too slow.
  # Surface compile errors immediately; full suite stays a manual / pre-push step.
  run_step "compile (gradle)" ./gradlew --quiet compileJava compileTestJava
fi

# --- Backend: Maven ---
if [ -f pom.xml ]; then
  if [ -x ./mvnw ]; then MVN=./mvnw; else MVN=mvn; fi
  run_step "compile (maven)" "$MVN" --quiet test-compile
fi

# --- Frontend: npm ---
if [ -f package.json ]; then
  has_script() { node -e "process.exit(require('./package.json').scripts?.['$1']?0:1)" 2>/dev/null; }
  uses_vitest() { grep -qE '"(vitest|@vitest/)"' package.json 2>/dev/null; }

  if has_script lint;      then run_step "lint"      npm run --silent lint;      fi
  if has_script typecheck; then run_step "typecheck" npm run --silent typecheck; fi
  # Test invocation must NOT hang on Jest's default watch mode. Vitest needs
  # --run for single-shot; Jest needs --watchAll=false. We only run tests when
  # the project script is sane (most modern setups end with --run / --ci).
  # If your test script defaults to watch mode, set CI=true in your .env or
  # update the script — this gate stays out of the way otherwise.
  if has_script test; then
    if uses_vitest; then
      run_step "test (vitest)" npm test --silent -- --run
    else
      # CI=true is the standard signal Jest, Karma, etc. respect to disable watch.
      run_step "test" env CI=true npm test --silent
    fi
  fi
fi

if [ "$ran_any" = "0" ]; then
  echo "verify.sh: no recognized stack — nothing to verify." >&2
  exit 0
fi

if [ "$fail" -ne 0 ]; then
  printf '\nverify.sh: one or more checks failed.\n' >&2
  exit 1
fi

printf '\nverify.sh: all checks passed.\n'
exit 0
