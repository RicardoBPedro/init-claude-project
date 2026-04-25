#!/usr/bin/env bash
# install.sh — single entry point for init-claude-project.
#
# Auto-detects what to do based on the target directory:
#   - empty / non-existent dir          → fresh install
#   - dir already has toolkit files     → upgrade (refresh managed assets)
#   - existing project, no toolkit      → fresh install (asks first)
#   - frontend vs backend               → detected from build files (asks if ambiguous)
#
# Usage (the only one most users need):
#   install.sh                       use the current directory (.) — handy when
#                                    running from the project root in an IDE terminal
#   install.sh <target-directory>    explicit target
#
# Overrides (for CI, scripted setups, edge cases):
#   install.sh [<target>] --type=frontend|backend|base   force project type
#   install.sh [<target>] --mode=install|upgrade         force mode
#   install.sh [<target>] --yes                          accept all defaults non-interactively
#   install.sh [<target>] --force-stack                  bypass stack-compatibility check
#                                                        (templates may not fit — adapt manually)
#
# Type semantics (decides which scripts/husky subdirs ship — not the addendum):
#   frontend   - React/Vue/Angular/Svelte/Astro/Solid/Preact (lint-staged pre-commit, npm scripts)
#   backend    - Java/Spring (Gradle wrapper, Spotless pre-commit)
#   base       - universal scaffolding only (no stack-specific pre-commit). Used
#                for Node-backend, Python, Go, Rust, Ruby, PHP, Elixir, .NET,
#                Flutter, Swift, Android — each still gets its own stack-<id>.md
#                CLAUDE.md addendum via the STACK env var.
#
#
# Legacy syntax (still supported, but the auto-detecting form above is preferred):
#   install.sh frontend|backend <target>
#   install.sh upgrade           <target>
#
# Environment:
#   ICP_REPO_URL    override git URL (default: github.com/RicardoBPedro/init-claude-project)
#   ICP_REPO_REF    pin to branch/tag (default: main — 'vX.Y.Z' for release pins)
#   ICP_HOME        clone location for the toolkit (default: ~/.init-claude-project)

set -euo pipefail

REPO_URL="${ICP_REPO_URL:-https://github.com/RicardoBPedro/init-claude-project.git}"
REPO_REF="${ICP_REPO_REF:-main}"
ICP_HOME="${ICP_HOME:-$HOME/.init-claude-project}"

usage() {
  sed -n '/^# install.sh/,/^$/{ /^#/!q; s/^# \{0,1\}//; p; }' "$0"
}

# --- Arg parsing ----------------------------------------------------------

target=""
forced_type=""
forced_mode=""
auto_yes=0
force_stack=0
positional=()

for arg in "$@"; do
  case "$arg" in
    -h|--help)        usage; exit 0 ;;
    --type=*)         forced_type="${arg#*=}" ;;
    --mode=*)         forced_mode="${arg#*=}" ;;
    --yes|-y)         auto_yes=1 ;;
    --force-stack)    force_stack=1 ;;
    -*)               echo "Unknown flag: $arg" >&2; usage >&2; exit 1 ;;
    *)                positional+=("$arg") ;;
  esac
done

# Legacy positional forms: `install.sh <type> <target>` or `install.sh upgrade <target>`.
# Zero args defaults to "." (current directory) — common case when running from
# a project root in an IDE-integrated terminal.
case "${#positional[@]}" in
  0) target="." ;;
  1) target="${positional[0]}" ;;
  2)
    case "${positional[0]}" in
      frontend|backend)
        forced_type="${positional[0]}"; forced_mode="install"; target="${positional[1]}" ;;
      upgrade)
        forced_mode="upgrade"; target="${positional[1]}" ;;
      *)
        echo "Unknown command: ${positional[0]}" >&2
        echo "Did you mean: install.sh ${positional[1]:-./project}  (auto-detect)?" >&2
        usage >&2; exit 1
        ;;
    esac
    ;;
  *)  echo "Too many positional args: ${positional[*]}" >&2; usage >&2; exit 1 ;;
esac

# --- Resolve toolkit location (local clone vs remote curl pipe) -----------

SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd -P 2>/dev/null || true)"
TOOLKIT_DIR=""
if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/lib/preflight.sh" ]; then
  TOOLKIT_DIR="$SCRIPT_DIR"
fi

if [ -z "$TOOLKIT_DIR" ]; then
  # Remote bootstrap: clone (or update) the toolkit to $ICP_HOME first.
  echo "[i] Bootstrapping init-claude-project toolkit to $ICP_HOME"
  if ! command -v git >/dev/null 2>&1; then
    echo "[x] git is required to bootstrap. Install from https://git-scm.com/downloads" >&2
    exit 1
  fi
  if [ -d "$ICP_HOME/.git" ]; then
    echo "[i] Updating existing checkout at $ICP_HOME (ref: $REPO_REF)"
    if ! git -C "$ICP_HOME" diff --quiet HEAD 2>/dev/null \
       || ! git -C "$ICP_HOME" diff --cached --quiet HEAD 2>/dev/null; then
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
  TOOLKIT_DIR="$ICP_HOME"
fi

# Source the helpers we need for detection. They were authored for the entry
# scripts but auto-detection lives at the dispatcher level — same library, no
# duplication.
# shellcheck source=lib/ui.sh
source "$TOOLKIT_DIR/lib/ui.sh"
# shellcheck source=lib/copy.sh
source "$TOOLKIT_DIR/lib/copy.sh"

# --- Auto-detection -------------------------------------------------------

# detect_mode <target>
# "upgrade" if any toolkit-managed file exists; "install" otherwise. Looks for
# strong markers (hook scripts, settings.json, naming.conf) — CLAUDE.md alone
# isn't enough since other tooling writes one too.
detect_mode() {
  local t="$1"
  [ -d "$t" ] || { echo "install"; return; }
  for marker in \
      ".husky/pre-push" \
      ".husky/commit-msg" \
      ".husky/naming.conf" \
      "scripts/branch-hygiene.sh" \
      "scripts/hook-stop-verify.sh" \
      "scripts/hook-prepush-validate.sh"; do
    [ -f "$t/$marker" ] && { echo "upgrade"; return; }
  done
  echo "install"
}

# Resolve final mode + type.
mode="${forced_mode:-$(detect_mode "$target")}"

# --- Stack validation (install mode only) ---
# Upgrade mode trusts the existing install. Install mode protects against e.g.
# dropping Java/React templates onto a Python/Go/Rust repo.
signals=""
inferred_type=""
if [ "$mode" = "install" ]; then
  signals="$(copy::stack_info "$target")"
  inferred_type="$(copy::supported_type "$signals")"
fi

type="${forced_type:-}"

# Bypass path: --force-stack with explicit --type skips ALL detection. For
# users who really know they want Java templates on a Kotlin/Scala project
# they're about to set up, etc.
if [ "$force_stack" = "1" ]; then
  if [ -z "$forced_type" ]; then
    ui::error "--force-stack requires --type=frontend|backend|base."
    exit 1
  fi
  ui::warn "--force-stack: skipping stack validation. You're on your own — adapt CLAUDE.md and scripts to fit."
elif [ "$mode" = "install" ]; then
  # 1. Forced --type that conflicts with detection → confirm or abort.
  if [ -n "$forced_type" ] && [ -n "$inferred_type" ] \
     && [ "$inferred_type" != "ambiguous" ] && [ "$forced_type" != "$inferred_type" ]; then
    ui::warn "You forced --type=$forced_type but the project's build files suggest '$inferred_type'."
    ui::dim "    Detected signals: $signals"
    if [ "$auto_yes" = "1" ]; then
      ui::error "Mismatched --type with --yes. Add --force-stack if intentional."
      exit 1
    fi
    if [ -r /dev/tty ]; then
      if ! ui::confirm "Continue anyway?"; then
        ui::warn "Aborted."
        exit 0
      fi
    else
      ui::error "Mismatched --type and no TTY for confirmation. Add --force-stack if intentional."
      exit 1
    fi
  fi

  # 2. No forced type → auto-pick / handle ambiguous / handle unsupported.
  if [ -z "$type" ]; then
    case "$inferred_type" in
      frontend|backend|base)
        type="$inferred_type"
        ;;
      ambiguous)
        ui::warn "Both backend (Java) and frontend (Node UI) build files detected — full-stack monorepo?"
        ui::dim "    Detected signals: $signals"
        if [ "$auto_yes" = "1" ]; then
          ui::error "--yes passed but type is ambiguous. Specify --type=frontend|backend."
          exit 1
        fi
        type=$(ui::ask "Which type to install? [frontend|backend]" "backend")
        ;;
      "")
        # No supported signal. Either truly empty (greenfield) or unsupported stack.
        unsup="$(copy::unsupported_signals "$signals")"
        if [ -n "$unsup" ]; then
          # Mobile / native have entirely different toolchains — call out the
          # context so the user understands why the templates wouldn't fit.
          mobile_msg=""
          case " $unsup " in
            *" flutter "*)        mobile_msg="Flutter" ;;
            *" swift-mobile "*)   mobile_msg="iOS / Swift mobile" ;;
            *" android-native "*) mobile_msg="Android native" ;;
            *" dotnet "*)         mobile_msg=".NET" ;;
          esac

          ui::warn "Detected stack(s) without dedicated templates: $unsup"
          echo ""
          if [ -n "$mobile_msg" ]; then
            ui::dim "    $mobile_msg projects use a fundamentally different toolchain"
            ui::dim "    (different test runners, lint chains, CI shape) — the Java/React"
            ui::dim "    templates wouldn't fit out of the box."
            echo ""
          fi
          ui::dim "    This toolkit ships dedicated stack-<id>.md addendums for:"
          ui::dim "      - Java/Spring (Gradle / Maven)"
          ui::dim "      - Frontend: React, Vue, Angular, Svelte, Astro, Solid, Preact"
          ui::dim "      - Node backend: NestJS, Fastify, Express, koa/hono/elysia (node-other)"
          ui::dim "      - Python: Django, FastAPI, Flask, data science"
          ui::dim "      - Go, Rust, Ruby on Rails, PHP/Laravel, Elixir/Phoenix, .NET/ASP.NET Core"
          ui::dim "      - Mobile: Flutter, iOS/Swift, Android/Kotlin"
          echo ""
          ui::dim "    Three options for your project:"
          ui::dim "      1) Install BASE only — universal value (gitflow, branch hygiene,"
          ui::dim "         commit conventions, naming.conf, memory seeds, quality-gate"
          ui::dim "         skeleton). No stack-specific addendum or scripts. RECOMMENDED."
          ui::dim "      2) Force-install Java/React templates (you adapt CLAUDE.md / scripts"
          ui::dim "         / hooks manually). Only useful if your stack is similar enough."
          ui::dim "      3) Abort — open an issue to track support for your stack:"
          ui::dim "         https://github.com/RicardoBPedro/init-claude-project/issues"
          echo ""

          if [ "$auto_yes" = "1" ]; then
            ui::error "--yes passed but the stack isn't supported."
            ui::dim "    Re-run with one of: --type=base | --type=frontend --force-stack | --type=backend --force-stack"
            exit 1
          fi

          choice=$(ui::ask "Choice [1=base / 2=force-stack / 3=abort]" "1")
          case "$choice" in
            1|base|BASE)
              type="base"
              ui::info "Installing BASE only."
              ;;
            2)
              if [ -r /dev/tty ]; then
                fb=$(ui::ask "Force which type? [frontend|backend]" "frontend")
              else
                fb="frontend"
              fi
              case "$fb" in frontend|backend) : ;; *) ui::error "Invalid choice: $fb"; exit 1 ;; esac
              type="$fb"; force_stack=1
              ui::warn "--force-stack: skipping stack validation. You're on your own — adapt CLAUDE.md and scripts to fit."
              ;;
            *)
              ui::warn "Aborted."; exit 0
              ;;
          esac
        else
          # No recognized stack signals at all — greenfield. Ask the user.
          if [ "$auto_yes" = "1" ]; then
            ui::error "No supported stack detected at $target and no --type passed."
            ui::dim "    Pass --type=frontend|backend|base (with --force-stack if you want to proceed without matching build files)."
            exit 1
          fi
          if [ -r /dev/tty ]; then
            type=$(ui::ask "No stack files found. Project type [frontend|backend|base]" "frontend")
          else
            type="frontend"
          fi
        fi
        ;;
    esac
  fi
fi

case "$type" in
  frontend|backend|base) : ;;
  "")
    if [ "$mode" = "install" ]; then
      ui::error "Project type unknown and could not be detected. Use --type=frontend|backend|base."
      exit 1
    fi
    ;;
  *) ui::error "Invalid --type: $type (expected frontend|backend|base)"; exit 1 ;;
esac

# --- Resolve primary stack (which stack-<id>.md addendum to merge in) ---
# In install mode, STACK is computed from detection signals via copy::primary_stack.
# Forces the right stack-specific CLAUDE.md addendum to load — works for ALL
# detectable stacks (frontend, backend, Python web/data, mobile, etc).
# Stays empty for upgrade mode (existing CLAUDE.md is preserved).
STACK=""
flavor=""
if [ "$mode" = "install" ] && [ "$force_stack" != "1" ]; then
  STACK="$(copy::primary_stack "$signals")"

  # Reconcile STACK with the resolved type. primary_stack prefers frontend in
  # monorepos — but if the user explicitly chose backend at the ambiguous prompt,
  # keep STACK aligned with their choice.
  case "$type:$STACK" in
    backend:react|backend:vue|backend:angular|backend:svelte|backend:astro|backend:solid|backend:preact)
      STACK="java-spring"
      ;;
    frontend:java-spring)
      # Rare: user picked frontend in a Java-only project. Use frontend flavor if
      # detected, else react as the greenfield default.
      STACK="$(copy::frontend_flavor "$signals")"
      [ -z "$STACK" ] && STACK="react"
      ;;
  esac

  # Greenfield defaults: empty signals + user chose a type.
  if [ -z "$STACK" ] && [ "$type" = "frontend" ]; then
    STACK="react"
  fi
  if [ -z "$STACK" ] && [ "$type" = "backend" ]; then
    STACK="java-spring"
  fi

  # Frontend flavor is derived from STACK for backwards compat with init-frontend.sh.
  case "$STACK" in
    react|vue|angular|svelte|astro|solid|preact) flavor="$STACK" ;;
  esac
fi
export STACK FRONTEND_FLAVOR="$flavor"

# Existing-but-no-marker confirmation — protect against installing on top of an
# unrelated populated directory by accident. Skipped when:
#   - mode was forced (user knows what they're doing)
#   - we recognized a stack signal (supported stack → expected fresh-install case;
#     unsupported stack already exited above)
#   - --force-stack was passed (user is bypassing all stack-related guards)
if [ -z "$forced_mode" ] \
   && [ "$mode" = "install" ] \
   && [ "$force_stack" != "1" ] \
   && [ -z "$signals" ] \
   && [ -d "$target" ] \
   && [ -n "$(ls -A "$target" 2>/dev/null | grep -v '^\.git$' || true)" ]; then
  echo ""
  ui::warn "$target is not empty and has no recognized stack files or toolkit markers."
  ui::dim "    Treating this as a FRESH install — files would be added (no overwrite)."
  if [ "$auto_yes" != "1" ] && [ -r /dev/tty ]; then
    if ! ui::confirm "Continue with install?"; then
      ui::warn "Aborted."
      exit 0
    fi
  fi
fi

# --- Dispatch -------------------------------------------------------------

ui::section "Resolved"
ui::info "Target:  $target"
ui::info "Mode:    $mode"
[ -n "$type" ]   && ui::info "Type:    $type"
[ -n "$STACK" ]  && ui::info "Stack:   $STACK"

case "$mode" in
  install)
    exec "$TOOLKIT_DIR/init-${type}.sh" "$target"
    ;;
  upgrade)
    exec "$TOOLKIT_DIR/init-upgrade.sh" "$target"
    ;;
  *)
    ui::error "Invalid mode: $mode (expected install|upgrade)"
    exit 1
    ;;
esac
