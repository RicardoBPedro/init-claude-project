#!/usr/bin/env bash
# preflight.sh — validate tools + Claude globals before install.
# Sourced or invoked by init-frontend.sh / init-backend.sh.

set -euo pipefail

__ICP_PREFLIGHT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__ICP_ROOT_DIR="$(cd "$__ICP_PREFLIGHT_DIR/.." && pwd)"
__ICP_MANIFEST="$__ICP_ROOT_DIR/preflight-manifest.json"

# shellcheck source=./ui.sh
source "$__ICP_PREFLIGHT_DIR/ui.sh"

# preflight::run <type:frontend|backend>
# Returns 0 if all required tools present (possibly after autoinstall), 1 otherwise.
preflight::run() {
  local type="${1:?type required (frontend|backend)}"
  local failed=0

  # --- Phase 1: bootstrap (bash, git, jq) ---
  # These are hardcoded because we can't parse the JSON manifest without jq.

  if ! command -v git >/dev/null 2>&1; then
    ui::error "git not found. Install from https://git-scm.com/downloads and re-run."
    return 1
  fi
  ui::ok "git"

  if ! command -v jq >/dev/null 2>&1; then
    ui::warn "jq not found (required to parse preflight manifest)"
    if ! preflight::_install_jq_bootstrap; then
      return 1
    fi
  fi
  ui::ok "jq"

  if ! ui::python >/dev/null 2>&1; then
    ui::warn "python3 not found (or broken — e.g. Microsoft Store stub on Windows)"
    preflight::_autoinstall_tool python3 || failed=1
  else
    ui::ok "python ($(ui::python))"
  fi

  # --- Phase 2: tools from manifest (type-scoped) ---
  ui::section "Checking tools for type=$type"

  local tools_to_check=()
  # Portable alternative to `mapfile -t` (which is bash 4+; macOS ships bash 3.2).
  while IFS= read -r line; do
    [ -n "$line" ] && tools_to_check+=("$line")
  done < <(
    jq -r --arg type "$type" \
      '.tools | to_entries[]
       | select(.value.required == true or ((.value.required_for // []) | any(. == $type)))
       | .key' \
      "$__ICP_MANIFEST"
  )

  local tool check_cmd
  for tool in "${tools_to_check[@]}"; do
    # Skip ones already verified in phase 1
    case "$tool" in git|bash|jq|python3) continue ;; esac
    check_cmd=$(jq -r --arg t "$tool" '.tools[$t].check' "$__ICP_MANIFEST")
    if eval "$check_cmd" >/dev/null 2>&1; then
      ui::ok "$tool"
    else
      ui::warn "$tool not found"
      preflight::_autoinstall_tool "$tool" || failed=1
    fi
  done

  # --- Phase 3: Claude globals ---
  ui::section "Checking Claude Code globals"

  preflight::_check_claude_files   || failed=1
  preflight::_check_claude_agents
  preflight::_check_claude_plugins

  # --- Summary ---
  ui::section "Preflight summary"
  if [ "$failed" = "0" ]; then
    ui::ok "All required tools and globals present. Ready to install."
    return 0
  fi
  ui::error "Preflight has unresolved issues. Fix the [x] items above and re-run."
  return 1
}

# Internal: bootstrap jq via OS package manager (needed before we can parse JSON).
preflight::_install_jq_bootstrap() {
  local os pm cmd
  os=$(ui::os_family)
  pm=$(ui::package_manager)
  case "${os}_${pm}" in
    linux_apt)    cmd="sudo apt-get update && sudo apt-get install -y jq" ;;
    linux_dnf)    cmd="sudo dnf install -y jq" ;;
    linux_pacman) cmd="sudo pacman -S --noconfirm jq" ;;
    darwin_brew)  cmd="brew install jq" ;;
    windows_winget) cmd="winget install -e --id jqlang.jq" ;;
    windows_scoop)  cmd="scoop install jq" ;;
    *)
      ui::error "No supported package manager for $os. Install jq manually: https://stedolan.github.io/jq/download/"
      return 1
      ;;
  esac
  ui::info "Will run: $cmd"
  if ui::confirm "Install jq now?" 1; then
    eval "$cmd"
    command -v jq >/dev/null 2>&1 || { ui::error "jq still missing after install."; return 1; }
    ui::ok "jq installed"
    return 0
  fi
  ui::error "Cannot proceed without jq."
  return 1
}

# Internal: autoinstall a single tool using the manifest.
preflight::_autoinstall_tool() {
  local tool="$1"
  local os pm key cmd guide_url guide_note check_cmd
  os=$(ui::os_family)
  pm=$(ui::package_manager)
  key="${os}_${pm}"

  cmd=$(jq -r --arg t "$tool" --arg k "$key" '.tools[$t].autoinstall[$k] // empty' "$__ICP_MANIFEST")
  # Fallback: any_npm (e.g. claude CLI)
  if [ -z "$cmd" ] || [ "$cmd" = "null" ]; then
    cmd=$(jq -r --arg t "$tool" '.tools[$t].autoinstall.any_npm // empty' "$__ICP_MANIFEST")
  fi

  if [ -n "$cmd" ] && [ "$cmd" != "null" ]; then
    # npm global installs fail with EACCES when Node was installed system-wide
    # (apt install nodejs, system Homebrew, etc.) because /usr/lib/node_modules
    # is root-owned. Pre-check writability so we skip the install and surface
    # actionable guidance instead of letting the user stare at an npm error wall.
    if [[ "$cmd" == *"npm install -g"* ]] && ! preflight::_npm_global_writable; then
      ui::warn "Can't autoinstall $tool: npm's global directory isn't writable by your user."
      preflight::_explain_npm_eacces "$tool" "$cmd"
      return 1
    fi

    ui::info "$tool → $cmd"
    if ui::confirm "Install $tool now?" 1; then
      eval "$cmd" || { ui::warn "$tool install command returned error."; }
      check_cmd=$(jq -r --arg t "$tool" '.tools[$t].check' "$__ICP_MANIFEST")
      if eval "$check_cmd" >/dev/null 2>&1; then
        ui::ok "$tool installed"
        return 0
      fi
      ui::error "$tool still missing after install."
      # Fallback diagnostics for npm globals: either the prefix wasn't writable
      # (EACCES the pre-check missed), or the install succeeded but the binary
      # isn't on PATH yet (npm prefix in user-managed location, shell needs
      # to re-source rc files).
      if [[ "$cmd" == *"npm install -g"* ]]; then
        if ! preflight::_npm_global_writable; then
          preflight::_explain_npm_eacces "$tool" "$cmd"
        else
          local prefix
          prefix=$(npm config get prefix 2>/dev/null || echo "<unknown>")
          echo ""
          ui::dim "    Install ran but '$tool' isn't on PATH. Likely a shell PATH issue."
          ui::dim "    Check that '$prefix/bin' is in PATH:"
          ui::dim "      echo \"\$PATH\" | tr ':' '\\n' | grep -F '$prefix/bin'"
          ui::dim "    If empty, add the directory to your shell rc and re-open the terminal."
          echo ""
        fi
      fi
      return 1
    fi
    ui::warn "Skipped $tool install."
    return 1
  fi

  # No autoinstall available — print manual guide.
  guide_url=$(jq -r --arg t "$tool" '.tools[$t].manual_guide_url // empty' "$__ICP_MANIFEST")
  guide_note=$(jq -r --arg t "$tool" '.tools[$t].manual_guide_note // empty' "$__ICP_MANIFEST")
  local optional
  optional=$(jq -r --arg t "$tool" '.tools[$t].optional // false' "$__ICP_MANIFEST")
  if [ "$optional" = "true" ]; then
    ui::warn "$tool is optional. Manual install: $guide_url"
    [ -n "$guide_note" ] && ui::dim "  $guide_note"
    return 0
  fi
  ui::error "$tool: no autoinstall for $os/$pm. Manual install: $guide_url"
  [ -n "$guide_note" ] && ui::dim "  $guide_note"
  return 1
}

# Internal: verify presence of Claude global files.
preflight::_check_claude_files() {
  local local_failed=0
  local path required note expanded
  while IFS= read -r entry; do
    path=$(jq -r '.path' <<<"$entry")
    required=$(jq -r '.required' <<<"$entry")
    note=$(jq -r '.note' <<<"$entry")
    expanded="${path/#\~/$HOME}"
    if [ -e "$expanded" ]; then
      ui::ok "$path"
    elif [ "$required" = "true" ]; then
      ui::error "$path missing (required). $note"
      local_failed=1
    else
      ui::warn "$path missing (optional). $note"
    fi
  done < <(jq -c '.claude_globals.files[]' "$__ICP_MANIFEST")
  return "$local_failed"
}

# Internal: warn on missing recommended agents.
preflight::_check_claude_agents() {
  local agents_dir="$HOME/.claude/agents"
  local missing=()
  while IFS= read -r agent; do
    [ -f "$agents_dir/$agent.md" ] || missing+=("$agent")
  done < <(jq -r '.claude_globals.agents.recommended[]' "$__ICP_MANIFEST")
  if [ ${#missing[@]} -gt 0 ]; then
    ui::warn "Missing recommended agents in $agents_dir: ${missing[*]}"
    ui::dim "  These are used by /audit and other workflows. Not fatal."
  else
    ui::ok "Recommended agents present"
  fi
}

# Internal: check whether `npm install -g` would succeed without sudo.
# Returns 0 if writable (or unknown — we'll let the install try), 1 if known-bad.
preflight::_npm_global_writable() {
  command -v npm >/dev/null 2>&1 || return 0  # no npm → install would fail for other reasons; don't preempt
  local prefix
  prefix=$(npm config get prefix 2>/dev/null || true)
  [ -z "$prefix" ] && return 0
  [ -d "$prefix" ] || return 0
  # Writable if either the prefix itself or its lib/node_modules subdir is
  # writable. (npm creates lib/node_modules on first global install if missing.)
  if [ -w "$prefix" ] || { [ -d "$prefix/lib/node_modules" ] && [ -w "$prefix/lib/node_modules" ]; }; then
    return 0
  fi
  return 1
}

# Internal: print diagnostic + link to the tool's manual install guide for npm
# EACCES failures. The fix is platform-specific (sudo / nvm / fnm / npm prefix
# migration / Windows installers / macOS Homebrew), so we don't try to enumerate
# remedies — the official docs cover their own platform matrix.
preflight::_explain_npm_eacces() {
  local tool="$1"
  local cmd="$2"
  local prefix who guide_url
  prefix=$(npm config get prefix 2>/dev/null || echo "<unknown>")
  who=$(whoami 2>/dev/null || echo "your user")
  guide_url=$(jq -r --arg t "$tool" '.tools[$t].manual_guide_url // empty' "$__ICP_MANIFEST")
  echo ""
  ui::dim "    npm global directory: $prefix (not writable by $who)"
  ui::dim "    Most common cause: Node was installed by a system package manager,"
  ui::dim "    so global packages land in a root-owned directory."
  echo ""
  if [ -n "$guide_url" ] && [ "$guide_url" != "null" ]; then
    ui::dim "    Install $tool manually following the official guide,"
    ui::dim "    then re-run this installer:"
    ui::dim "      $guide_url"
  else
    ui::dim "    Install $tool manually, then re-run this installer."
  fi
  echo ""
}

# Internal: warn on missing enabled plugins.
preflight::_check_claude_plugins() {
  local settings="$HOME/.claude/settings.json"
  [ -f "$settings" ] || { ui::warn "$settings missing — skipping plugin check"; return 0; }
  local missing=()
  while IFS= read -r plugin; do
    local key="${plugin}@claude-plugins-official"
    local enabled
    enabled=$(jq -r --arg p "$key" '.enabledPlugins[$p] // false' "$settings")
    [ "$enabled" = "true" ] || missing+=("$plugin")
  done < <(jq -r '.claude_globals.plugins.recommended[]' "$__ICP_MANIFEST")
  if [ ${#missing[@]} -gt 0 ]; then
    ui::warn "Recommended plugins not enabled: ${missing[*]}"
    ui::dim "  Enable via Claude Code UI or edit ~/.claude/settings.json > enabledPlugins."
  else
    ui::ok "Recommended plugins enabled"
  fi
}
