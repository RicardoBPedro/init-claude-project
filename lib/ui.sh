#!/usr/bin/env bash
# ui.sh — colored output + prompts + OS detection.
# Sourced by preflight.sh, copy.sh, and entry points. Don't run directly.

# Guard against double-sourcing
if [ -n "${__ICP_UI_SOURCED:-}" ]; then return 0; fi
__ICP_UI_SOURCED=1

# Colors — disabled when stdout isn't a TTY (CI, pipes), when NO_COLOR is set
# (https://no-color.org), or when ICP_NO_COLOR=1 is forced.
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ "${ICP_NO_COLOR:-0}" != "1" ]; then
  C_RED=$'\033[0;31m'
  C_GREEN=$'\033[0;32m'
  C_YELLOW=$'\033[0;33m'
  C_BLUE=$'\033[0;34m'
  C_CYAN=$'\033[0;36m'
  C_DIM=$'\033[2m'
  C_BOLD=$'\033[1m'
  C_RESET=$'\033[0m'
else
  C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""; C_CYAN=""; C_DIM=""; C_BOLD=""; C_RESET=""
fi

# Symbol set — Unicode by default when locale advertises UTF-8, ASCII fallback
# otherwise. Override via ICP_UNICODE=0|1 (e.g. force on for Git Bash, which
# renders UTF-8 fine but may have empty LANG).
case "${ICP_UNICODE:-auto}" in
  0|no|false|off) __ICP_UTF8=0 ;;
  1|yes|true|on)  __ICP_UTF8=1 ;;
  *)
    case "${LC_ALL:-}${LC_CTYPE:-}${LANG:-}" in
      *UTF-8*|*utf-8*|*UTF8*|*utf8*) __ICP_UTF8=1 ;;
      *) __ICP_UTF8=0 ;;
    esac
    ;;
esac

if [ "$__ICP_UTF8" = "1" ]; then
  S_INFO="ℹ"
  S_OK="✓"
  S_WARN="⚠"
  S_ERROR="✗"
  S_BULLET="•"
  S_PROMPT="❯"
  S_SECTION="▸"
else
  S_INFO="i"
  S_OK="+"
  S_WARN="!"
  S_ERROR="x"
  S_BULLET="*"
  S_PROMPT=">"
  S_SECTION=">"
fi

ui::info()    { printf '  %s%s%s %s\n' "$C_CYAN"   "$S_INFO"  "$C_RESET" "$*"; }
ui::ok()      { printf '  %s%s%s %s\n' "$C_GREEN"  "$S_OK"    "$C_RESET" "$*"; }
ui::warn()    { printf '  %s%s%s %s\n' "$C_YELLOW" "$S_WARN"  "$C_RESET" "$*" >&2; }
ui::error()   { printf '  %s%s%s %s\n' "$C_RED"    "$S_ERROR" "$C_RESET" "$*" >&2; }
ui::dim()     { printf '%s%s%s\n'      "$C_DIM"    "$*"       "$C_RESET"; }
ui::bullet()  { printf '    %s%s%s %s\n' "$C_DIM"  "$S_BULLET" "$C_RESET" "$*"; }
ui::section() { printf '\n%s%s %s%s\n' "$C_CYAN$C_BOLD" "$S_SECTION" "$*" "$C_RESET"; }

# ui::confirm <prompt> [default_yes]
# Returns 0 if yes, 1 if no. Default NO unless default_yes=1.
ui::confirm() {
  local prompt="$1"
  local default_yes="${2:-0}"
  local default_str="[y/N]"
  [ "$default_yes" = "1" ] && default_str="[Y/n]"
  local reply
  printf '  %s%s%s %s %s%s%s ' \
    "$C_CYAN" "$S_PROMPT" "$C_RESET" \
    "$prompt" \
    "$C_DIM" "$default_str" "$C_RESET" >&2
  # Read from the controlling terminal so prompts work even when stdin is
  # piped (curl | bash bootstrap path).
  if [ -r /dev/tty ]; then
    read -r reply </dev/tty || reply=""
  else
    read -r reply || reply=""
  fi
  if [ -z "$reply" ]; then
    [ "$default_yes" = "1" ] && return 0 || return 1
  fi
  case "$reply" in
    y|Y|yes|YES|s|S|sim|SIM) return 0 ;;
    *) return 1 ;;
  esac
}

# ui::ask <prompt> [default_value]
# Echoes the user's response to stdout. Empty + default → default.
ui::ask() {
  local prompt="$1"
  local default="${2:-}"
  local reply
  local default_hint=""
  [ -n "$default" ] && default_hint=" $C_DIM[$default]$C_RESET"
  printf '  %s%s%s %s%s: ' \
    "$C_CYAN" "$S_PROMPT" "$C_RESET" \
    "$prompt" "$default_hint" >&2
  if [ -r /dev/tty ]; then
    read -r reply </dev/tty || reply=""
  else
    read -r reply || reply=""
  fi
  if [ -z "$reply" ] && [ -n "$default" ]; then
    printf '%s' "$default"
  else
    printf '%s' "$reply"
  fi
}

# Detect OS family (linux | darwin | windows | unknown)
ui::os_family() {
  case "$(uname -s)" in
    Linux*)                echo "linux" ;;
    Darwin*)               echo "darwin" ;;
    MINGW*|MSYS*|CYGWIN*)  echo "windows" ;;
    *)                     echo "unknown" ;;
  esac
}

# Detect available package manager (apt | dnf | pacman | brew | winget | scoop | none)
ui::package_manager() {
  case "$(ui::os_family)" in
    linux)
      if   command -v apt-get >/dev/null 2>&1; then echo "apt"
      elif command -v dnf     >/dev/null 2>&1; then echo "dnf"
      elif command -v pacman  >/dev/null 2>&1; then echo "pacman"
      else echo "none"; fi ;;
    darwin)
      command -v brew >/dev/null 2>&1 && echo "brew" || echo "none" ;;
    windows)
      if   command -v winget     >/dev/null 2>&1; then echo "winget"
      elif command -v winget.exe >/dev/null 2>&1; then echo "winget"
      elif command -v scoop      >/dev/null 2>&1; then echo "scoop"
      else echo "none"; fi ;;
    *) echo "none" ;;
  esac
}

# Validate a git branch name. Returns 0 if valid per git's rules, 1 otherwise.
# Rejects empty strings, whitespace, glob characters, and anything git itself
# wouldn't accept via `git check-ref-format`.
ui::valid_branch_name() {
  local name="$1"
  [ -z "$name" ] && return 1
  git check-ref-format --branch "$name" >/dev/null 2>&1
}

# Resolve the working python interpreter (python3 or python). Handles the
# Windows/Microsoft-Store stub where `python3` exists in PATH but exits non-zero
# when invoked (it prompts to install from Store).
ui::python() {
  if python3 --version >/dev/null 2>&1; then
    echo "python3"
  elif python --version >/dev/null 2>&1; then
    echo "python"
  else
    return 1
  fi
}

# Resolve an absolute path cross-platform (realpath missing on some Git Bash)
ui::abs_path() {
  local target="$1"
  if command -v realpath >/dev/null 2>&1; then
    realpath "$target"
  elif command -v cygpath >/dev/null 2>&1; then
    cygpath -a "$target"
  else
    # Fallback: resolve via cd
    ( cd "$(dirname "$target")" && printf '%s/%s' "$(pwd)" "$(basename "$target")" )
  fi
}
