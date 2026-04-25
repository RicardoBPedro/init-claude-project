#!/usr/bin/env bash
# copy.sh — file operations: conflict detection, template copy, placeholder
# substitution, project-local memory seeding. Sourced by init-frontend.sh /
# init-backend.sh. Don't run directly.

set -euo pipefail

__ICP_COPY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__ICP_COPY_ROOT="$(cd "$__ICP_COPY_DIR/.." && pwd)"

# shellcheck source=./ui.sh
source "$__ICP_COPY_DIR/ui.sh"

# copy::check_conflicts <target_dir>
# Aborts if any file the installer would overwrite already exists. Runs BEFORE
# prompts / copy, so the user fails fast and doesn't waste time answering.
# In upgrade mode (ICP_MODE=upgrade), skipped — conflicts are EXPECTED and
# resolved interactively by copy::merge_file inside each copy::* function.
copy::check_conflicts() {
  [ "${ICP_MODE:-install}" = "upgrade" ] && return 0
  local target="$1"
  local conflicts=()

  [ -f "$target/CLAUDE.md" ]                 && conflicts+=("CLAUDE.md")
  [ -f "$target/docs/troubleshooting.md" ]   && conflicts+=("docs/troubleshooting.md")
  [ -f "$target/.claude/settings.json" ]     && conflicts+=(".claude/settings.json")

  local s
  for s in branch-hygiene.sh branch-start.sh check-secrets.sh check-todo-budget.sh seed-memory.sh test-backend.sh verify.sh hook-prepush-validate.sh hook-sessionstart.sh hook-stop-verify.sh; do
    [ -f "$target/scripts/$s" ] && conflicts+=("scripts/$s")
  done

  local h
  for h in commit-msg pre-push pre-commit naming.conf; do
    [ -f "$target/.husky/$h" ] && conflicts+=(".husky/$h")
  done

  if [ ${#conflicts[@]} -gt 0 ]; then
    ui::error "Target directory already contains files this installer would overwrite:"
    local f
    for f in "${conflicts[@]}"; do
      printf '  - %s/%s\n' "$target" "$f" >&2
    done
    echo "" >&2
    ui::dim "  To proceed: back up / remove the conflicting files, or choose a fresh target directory." >&2
    ui::dim "  This installer deliberately refuses to overwrite existing config to protect your work." >&2
    return 1
  fi
  return 0
}

# copy::substitute <file> [strip_meta]
# Replaces placeholders in-place using env vars:
#   PROJECT_SUMMARY, MAIN_BRANCH, STAGING_BRANCH, PROJECT_ROOT.
# If strip_meta=1, ALSO strips template bookkeeping after substitution: HTML
# comments in markdown and "_comment" fields in JSON. Order is critical —
# substitution must run FIRST so JSON becomes parseable, then we strip.
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

# Step 0: if STAGING_BRANCH is empty, the templates would render empty backticks
# (in markdown: "`develop` / `` / `main`") or trailing/duplicate tokens (in
# scripts: "PROTECTED='main ... develop main '"). Collapse those surrounding
# patterns BEFORE the generic placeholder replacement so the output is clean.
if not subs["{{STAGING_BRANCH}}"]:
    for pat in (
        " / `{{STAGING_BRANCH}}`",
        "`{{STAGING_BRANCH}}` / ",
        ", `{{STAGING_BRANCH}}`",
        "`{{STAGING_BRANCH}}`, ",
        " {{STAGING_BRANCH}}",   # leading-space form used inside shell strings
    ):
        content = content.replace(pat, "")

# Step 1: substitute placeholders. For JSON this produces valid JSON; for
# markdown it fills in project metadata.
for k, v in subs.items():
    content = content.replace(k, v)

# Step 2 (optional): strip template bookkeeping. Runs AFTER substitution so
# the JSON parser sees valid content.
if strip:
    # Strip HTML comments (<!-- ... -->) — used in md_sources for template notes.
    content = re.sub(r"<!--.*?-->\s*", "", content, flags=re.DOTALL)
    # For JSON (or .tmpl files that produce JSON), drop top-level `_comment` keys.
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
            pass  # Not valid JSON — leave content as-is.

with open(path, "w", encoding="utf-8") as f:
    f.write(content)
PY
}

# copy::md_sources <type:frontend|backend> <target_dir>
# Reads WITH_BRAZIL + WITH_MUTATION env vars (0/1) to decide whether to append
# opt-in addendums. Opt-in keeps the default CLAUDE.md as small as possible —
# every token saved multiplies across every session every user has.
copy::md_sources() {
  local type="$1"
  local target="$2"
  local src="$__ICP_COPY_ROOT/md_sources"
  local with_brazil="${WITH_BRAZIL:-0}"
  local with_mutation="${WITH_MUTATION:-0}"
  local mode="${ICP_MODE:-install}"
  local flavor="${FRONTEND_FLAVOR:-react}"

  # Pick the stack-specific addendum. STACK env (set by install.sh from
  # copy::primary_stack) directly names the file: stack-$STACK.md. Falls back
  # to a sensible default per type when STACK isn't set or the file is missing.
  local type_md=""
  if [ -n "${STACK:-}" ] && [ -f "$src/CLAUDE/stack-$STACK.md" ]; then
    type_md="$src/CLAUDE/stack-$STACK.md"
  else
    # No STACK or missing file — fall back to type-based defaults.
    case "$type" in
      base)
        type_md=""  # no addendum — base.md alone
        ;;
      frontend)
        if [ -f "$src/CLAUDE/stack-$flavor.md" ]; then
          type_md="$src/CLAUDE/stack-$flavor.md"
        else
          type_md="$src/CLAUDE/stack-react.md"
          ui::dim "  (no stack-$flavor.md — falling back to React addendum; adapt CLAUDE.md as needed)"
        fi
        ;;
      backend)
        type_md="$src/CLAUDE/stack-java-spring.md"
        ;;
    esac
  fi

  mkdir -p "$target"
  if [ "$mode" = "upgrade" ] && [ -f "$target/CLAUDE.md" ]; then
    local hint
    hint=$([ -n "$type_md" ] && basename "$type_md" || echo "base.md")
    ui::dim "  ~ CLAUDE.md  (kept — user customizations preserved; review $hint for new sections to merge)"
  else
    ui::info "Writing CLAUDE.md"
    {
      cat "$src/CLAUDE/base.md"
      if [ -n "$type_md" ] && [ -f "$type_md" ]; then
        printf '\n\n---\n\n'
        cat "$type_md"
      fi
      if [ "$with_brazil" = "1" ] && [ -f "$src/CLAUDE/brazil.md" ]; then
        printf '\n\n---\n\n'
        cat "$src/CLAUDE/brazil.md"
      fi
      # Mutation testing only applies when there's a stack — base type skips it.
      if [ "$type" != "base" ] && [ "$with_mutation" = "1" ] && [ -f "$src/CLAUDE/mutation-$type.md" ]; then
        printf '\n\n---\n\n'
        cat "$src/CLAUDE/mutation-$type.md"
      fi
    } > "$target/CLAUDE.md"
    copy::substitute "$target/CLAUDE.md" 1
  fi

  mkdir -p "$target/docs"
  if [ "$mode" = "upgrade" ]; then
    copy::merge_file "$src/docs/troubleshooting.md" "$target/docs/troubleshooting.md" 1 1
  else
    ui::info "Writing docs/troubleshooting.md"
    cp "$src/docs/troubleshooting.md" "$target/docs/troubleshooting.md"
    copy::substitute "$target/docs/troubleshooting.md" 1
  fi

  # ADR scaffold — see CLAUDE.md > Decision log. Empty .gitkeep so the dir
  # exists from day 1 and Claude has a known target for design-decision notes.
  # Idempotent on upgrade (existing .gitkeep is left alone).
  mkdir -p "$target/docs/decisions"
  [ -f "$target/docs/decisions/.gitkeep" ] || : > "$target/docs/decisions/.gitkeep"
}

# copy::memory_seeds <target_dir>
# Writes universal memory seeds into $target/.claude/memory-seeds/. Claude Code's
# actual memory dir is ~/.claude/projects/<hashed-path>/memory/ — scripts/seed-memory.sh
# (installed separately) does the final copy with correct cross-platform hashing.
copy::memory_seeds() {
  local target="$1"
  local src="$__ICP_COPY_ROOT/md_sources/memory-seeds"
  local dest="$target/.claude/memory-seeds"
  local mode="${ICP_MODE:-install}"

  mkdir -p "$dest"
  if [ "$mode" = "install" ]; then
    ui::info "Writing memory seeds to .claude/memory-seeds/"
  fi
  local f name
  for f in "$src"/*.md; do
    name=$(basename "$f")
    if [ "$mode" = "upgrade" ] && [ -f "$dest/$name" ]; then
      ui::dim "  = .claude/memory-seeds/$name  (kept)"
      continue
    fi
    cp "$f" "$dest/$name"
    [ "$mode" = "upgrade" ] && ui::dim "  + .claude/memory-seeds/$name  (new)"
  done

  # README inside memory-seeds — kept on upgrade if user has tweaked it.
  if [ "$mode" = "upgrade" ] && [ -f "$dest/README.md" ]; then
    ui::dim "  = .claude/memory-seeds/README.md  (kept)"
    return 0
  fi
  cat > "$dest/README.md" <<'EOF'
# Memory seeds

Universal Claude Code memories (feedback + references) bundled with this project by `init-claude-project`.

Claude Code stores project memory at `~/.claude/projects/<hashed-project-path>/memory/`. The dir is created lazily on the first Claude session in this project.

## Activation

After running `claude` at least once in this project (so Claude creates the memory dir), run:

```bash
bash scripts/seed-memory.sh
```

That script computes the hashed path correctly for your OS and copies each file under this folder into Claude's real memory dir, skipping files that already exist.

## What's in here

- `feedback_*.md` — 6 universal feedback memories (branch hygiene, coverage ratchet, Opus for audits, docs-with-code, Claude config authorization, global vs project skills)
- `reference_testing_standard.md` — testing discipline summary (6 principles + zero-tolerance)
- `MEMORY.md` — index that gets prepended to the project's MEMORY.md

Review these before activating. Edit freely — they're yours.
EOF
}

# copy::scripts <type> <target_dir>
# Copies scripts/common/* + scripts/<type>/* and substitutes placeholders in
# the hook helpers that reference user-chosen branch names.
# In upgrade mode: per-file merge with prompt on conflict; verify.sh is treated
# as user-config (kept if it already exists).
copy::scripts() {
  local type="$1"
  local target="$2"
  local src="$__ICP_COPY_ROOT/templates/scripts"
  local mode="${ICP_MODE:-install}"

  mkdir -p "$target/scripts"

  if [ "$mode" = "upgrade" ]; then
    local f base
    if [ -d "$src/common" ]; then
      for f in "$src/common/"*; do
        base=$(basename "$f")
        if [ "$base" = "verify.sh" ] && [ -f "$target/scripts/verify.sh" ]; then
          ui::dim "  ~ scripts/verify.sh  (kept — quality gate is user-customizable)"
          continue
        fi
        copy::merge_file "$f" "$target/scripts/$base" 1 0
      done
    fi
    if [ -d "$src/$type" ]; then
      for f in "$src/$type/"*; do
        copy::merge_file "$f" "$target/scripts/$(basename "$f")" 1 0
      done
    fi
  else
    ui::info "Installing scripts/"
    [ -d "$src/common" ] && cp -R "$src/common/." "$target/scripts/"
    [ -d "$src/$type" ]  && cp -R "$src/$type/."  "$target/scripts/"
  fi

  find "$target/scripts" -type f -name '*.sh' -exec chmod +x {} + 2>/dev/null || true

  # hook-prepush-validate.sh has {{MAIN_BRANCH}}/{{STAGING_BRANCH}} in its PROTECTED list.
  # In upgrade mode the merge_file pass already substituted; this pass is a no-op then.
  [ "$mode" = "install" ] && [ -f "$target/scripts/hook-prepush-validate.sh" ] && \
    copy::substitute "$target/scripts/hook-prepush-validate.sh" 0
}

# copy::naming_disable <conf_file> <KEY>
# Sets KEY='' on the matching uncommented line in naming.conf — turns the check
# into a no-op without removing the documentation around it. Idempotent.
copy::naming_disable() {
  local file="$1"
  local key="$2"
  [ -f "$file" ] || return 0
  PYICP_FILE="$file" PYICP_KEY="$key" "$(ui::python)" - <<'PY'
import os, re
path = os.environ["PYICP_FILE"]
key = os.environ["PYICP_KEY"]
with open(path, "r", encoding="utf-8") as f:
    lines = f.readlines()
pat = re.compile(rf"^(\s*){re.escape(key)}\s*=.*$")
for i, line in enumerate(lines):
    if pat.match(line):
        lines[i] = f"{key}=''\n"
        break
with open(path, "w", encoding="utf-8") as f:
    f.writelines(lines)
PY
}

# copy::detect_type <target_dir>
# Returns "frontend" / "backend" / "" based on marker files. Used by upgrade
# mode to skip asking what kind of project this is. Coarse detection — for
# install-mode validation use copy::stack_info / copy::supported_type instead.
copy::detect_type() {
  local target="$1"
  if [ -f "$target/build.gradle" ] || [ -f "$target/build.gradle.kts" ] || [ -f "$target/pom.xml" ]; then
    echo "backend"
  elif [ -f "$target/package.json" ]; then
    echo "frontend"
  else
    echo ""
  fi
}

# copy::stack_info <target_dir>
# Echoes a space-separated list of detected stack signals — granular form.
# Each signal corresponds to a specific stack-<id>.md addendum file.
#
# Frontend (signals → stack id):
#   node-react       (also covers Next, Remix, Gatsby)
#   node-vue         (also covers Nuxt)
#   node-angular
#   node-svelte      (also covers SvelteKit)
#   node-astro
#   node-solid
#   node-preact
#
# Backend (Node):
#   node-nest        (@nestjs/core)
#   node-express     (express)
#   node-fastify     (fastify)
#   node-other       (koa, hono, hapi, elysia, @trpc/server, or any package.json without recognized frameworks)
#
# Backend (Java):
#   java-spring      (Spring Boot — assumed when Java/Gradle/Maven detected)
#   android-native   (build.gradle with com.android.application)
#
# Backend (Python — variant inferred from deps):
#   python-django    (Django)
#   python-fastapi   (fastapi)
#   python-flask     (Flask)
#   python-data      (numpy/pandas/polars/scikit-learn — data science)
#   python-other     (Python project without recognized framework)
#
# Backend (other languages):
#   go               (go.mod)
#   rust             (Cargo.toml)
#   ruby-rails       (Gemfile with rails)
#   ruby-other       (Gemfile without rails)
#   php-laravel      (composer.json with laravel/framework)
#   php-other        (composer.json without Laravel)
#   elixir-phoenix   (mix.exs with phoenix)
#   elixir-other     (mix.exs without Phoenix)
#   dotnet-aspnet    (*.csproj / *.sln with ASP.NET reference)
#   dotnet-other     (*.csproj / *.sln without ASP.NET)
#
# Mobile:
#   flutter          (pubspec.yaml WITH flutter)
#   dart-pure        (pubspec.yaml without flutter — server-side / CLI Dart)
#   swift-mobile     (Package.swift / *.xcodeproj / *.xcworkspace)
copy::stack_info() {
  local t="$1"
  local signals=()
  [ -d "$t" ] || { echo ""; return; }

  # --- Java backend / Android ---
  if [ -f "$t/build.gradle" ] || [ -f "$t/build.gradle.kts" ]; then
    if grep -qE 'com\.android\.(application|library)' "$t"/build.gradle* "$t"/settings.gradle* 2>/dev/null; then
      signals+=("android-native")
    else
      signals+=("java-spring")
    fi
  fi
  [ -f "$t/pom.xml" ] && signals+=("java-spring")

  # --- Node — frontend flavor first, backend framework second ---
  if [ -f "$t/package.json" ]; then
    local pj
    pj=$(cat "$t/package.json" 2>/dev/null)
    local matched=0

    # Frontend frameworks (most-specific first so Next → react, Nuxt → vue).
    if   echo "$pj" | grep -qE '"(@angular/core|@angular/cli)"'; then
      signals+=("node-angular"); matched=1
    elif echo "$pj" | grep -qE '"(svelte|@sveltejs/kit)"'; then
      signals+=("node-svelte"); matched=1
    elif echo "$pj" | grep -qE '"(vue|nuxt|@vue/cli|@nuxt/)"'; then
      signals+=("node-vue"); matched=1
    elif echo "$pj" | grep -qE '"astro"'; then
      signals+=("node-astro"); matched=1
    elif echo "$pj" | grep -qE '"solid-js"'; then
      signals+=("node-solid"); matched=1
    elif echo "$pj" | grep -qE '"react"' || echo "$pj" | grep -qE '"(next|remix|gatsby|@remix-run/)"'; then
      signals+=("node-react"); matched=1
    elif echo "$pj" | grep -qE '"preact"'; then
      signals+=("node-preact"); matched=1
    fi

    # Node backend frameworks (only checked when frontend didn't match).
    if [ "$matched" = "0" ]; then
      if   echo "$pj" | grep -qE '"@nestjs/core"'; then
        signals+=("node-nest")
      elif echo "$pj" | grep -qE '"fastify"'; then
        signals+=("node-fastify")
      elif echo "$pj" | grep -qE '"express"'; then
        signals+=("node-express")
      elif echo "$pj" | grep -qE '"(koa|hapi|hono|elysia|@trpc/server)"'; then
        signals+=("node-other")
      else
        signals+=("node-other")
      fi
    fi
  fi

  # --- Python — variant inferred from deps in pyproject.toml or requirements.txt ---
  if [ -f "$t/pyproject.toml" ] || [ -f "$t/requirements.txt" ] || [ -f "$t/Pipfile" ] || [ -f "$t/setup.py" ]; then
    local py_deps
    py_deps=$(
      cat "$t/pyproject.toml" "$t/requirements.txt" "$t/Pipfile" "$t/setup.py" 2>/dev/null \
        | tr '[:upper:]' '[:lower:]'
    )
    if   echo "$py_deps" | grep -qE '(^|[^a-z])django([^a-z]|$)'; then
      signals+=("python-django")
    elif echo "$py_deps" | grep -qE '(^|[^a-z])fastapi([^a-z]|$)'; then
      signals+=("python-fastapi")
    elif echo "$py_deps" | grep -qE '(^|[^a-z])flask([^a-z]|$)'; then
      signals+=("python-flask")
    elif echo "$py_deps" | grep -qE '(numpy|pandas|polars|scikit-learn|jupyter|torch|tensorflow|matplotlib)'; then
      signals+=("python-data")
    else
      signals+=("python-other")
    fi
  fi
  [ -f "$t/go.mod" ]     && signals+=("go")
  [ -f "$t/Cargo.toml" ] && signals+=("rust")

  # Ruby — Rails vs other
  if [ -f "$t/Gemfile" ]; then
    if grep -qE "^\s*gem\s+['\"]rails['\"]" "$t/Gemfile" 2>/dev/null; then
      signals+=("ruby-rails")
    else
      signals+=("ruby-other")
    fi
  fi

  # PHP — Laravel vs other
  if [ -f "$t/composer.json" ]; then
    if grep -q '"laravel/framework"' "$t/composer.json" 2>/dev/null; then
      signals+=("php-laravel")
    else
      signals+=("php-other")
    fi
  fi

  # Elixir — Phoenix vs other
  if [ -f "$t/mix.exs" ]; then
    if grep -qE ':phoenix(_|,|\s|$)' "$t/mix.exs" 2>/dev/null; then
      signals+=("elixir-phoenix")
    else
      signals+=("elixir-other")
    fi
  fi

  # Flutter vs pure Dart
  if [ -f "$t/pubspec.yaml" ]; then
    if grep -qE '^\s*flutter\s*:' "$t/pubspec.yaml" 2>/dev/null \
       || grep -qE 'sdk:\s*flutter' "$t/pubspec.yaml" 2>/dev/null; then
      signals+=("flutter")
    else
      signals+=("dart-pure")
    fi
  fi

  # .NET — ASP.NET Core vs other (look for Microsoft.AspNetCore in any .csproj)
  local f csproj_found=0 has_aspnet=0
  for f in "$t"/*.csproj; do
    [ -e "$f" ] || continue
    csproj_found=1
    grep -qE 'Microsoft\.AspNetCore|Sdk="Microsoft\.NET\.Sdk\.Web"' "$f" 2>/dev/null && has_aspnet=1
  done
  if [ "$csproj_found" = "1" ]; then
    [ "$has_aspnet" = "1" ] && signals+=("dotnet-aspnet") || signals+=("dotnet-other")
  else
    for f in "$t"/*.sln; do
      [ -e "$f" ] || continue
      signals+=("dotnet-other"); break
    done
  fi

  # Swift / iOS — Package.swift, .xcodeproj, .xcworkspace
  if [ -f "$t/Package.swift" ]; then
    signals+=("swift-mobile")
  else
    for f in "$t"/*.xcodeproj "$t"/*.xcworkspace; do
      [ -e "$f" ] || continue
      signals+=("swift-mobile"); break
    done
  fi

  echo "${signals[*]:-}"
}

# copy::primary_stack <signals-string>
# Returns the canonical stack id (one of the stack-<id>.md files) when exactly
# one is detected. For ambiguous/multiple/empty, returns "".
#
# Frontend always wins over backend in monorepo cases — most users running
# `install.sh` against a frontend dir expect the frontend addendum.
# Caller (install.sh) handles ambiguity at a higher level if needed.
copy::primary_stack() {
  local s=" $1 "
  # Frontend (preferred when detected)
  case "$s" in
    *" node-react "*)    echo "react";   return ;;
    *" node-vue "*)      echo "vue";     return ;;
    *" node-angular "*)  echo "angular"; return ;;
    *" node-svelte "*)   echo "svelte";  return ;;
    *" node-astro "*)    echo "astro";   return ;;
    *" node-solid "*)    echo "solid";   return ;;
    *" node-preact "*)   echo "preact";  return ;;
  esac
  # Java / Spring (highest-priority backend)
  case "$s" in
    *" java-spring "*)   echo "java-spring"; return ;;
  esac
  # Node backend
  case "$s" in
    *" node-nest "*)     echo "node-nest";    return ;;
    *" node-fastify "*)  echo "node-fastify"; return ;;
    *" node-express "*)  echo "node-express"; return ;;
    *" node-other "*)    echo "node-other";   return ;;
  esac
  # Python web vs data
  case "$s" in
    *" python-django "*)  echo "python-django";  return ;;
    *" python-fastapi "*) echo "python-fastapi"; return ;;
    *" python-flask "*)   echo "python-flask";   return ;;
    *" python-data "*)    echo "python-data";    return ;;
    *" python-other "*)   echo "python-other";   return ;;
  esac
  # Other backends
  case "$s" in
    *" go "*)              echo "go";              return ;;
    *" rust "*)            echo "rust";            return ;;
    *" ruby-rails "*)      echo "ruby-rails";      return ;;
    *" ruby-other "*)      echo "ruby-other";      return ;;
    *" php-laravel "*)     echo "php-laravel";     return ;;
    *" php-other "*)       echo "php-other";       return ;;
    *" elixir-phoenix "*)  echo "elixir-phoenix";  return ;;
    *" elixir-other "*)    echo "elixir-other";    return ;;
    *" dotnet-aspnet "*)   echo "dotnet-aspnet";   return ;;
    *" dotnet-other "*)    echo "dotnet-other";    return ;;
  esac
  # Mobile
  case "$s" in
    *" flutter "*)         echo "flutter";         return ;;
    *" swift-mobile "*)    echo "swift-mobile";    return ;;
    *" android-native "*)  echo "android-kotlin";  return ;;
    *" dart-pure "*)       echo "dart-pure";       return ;;
  esac
  echo ""
}

# copy::stack_to_type <stack-id>
# Maps a primary stack id to the install type (frontend / backend / base) that
# determines which scripts/husky subdirs get copied. Stacks without dedicated
# scripts use "base".
copy::stack_to_type() {
  case "$1" in
    react|vue|angular|svelte|astro|solid|preact)  echo "frontend" ;;
    java-spring)                                    echo "backend"  ;;
    *)                                              echo "base"     ;;
  esac
}

# copy::frontend_flavor <signals-string>
# Backwards-compat shim — prefer copy::primary_stack. Returns the frontend
# framework name when one is detected, "" otherwise.
copy::frontend_flavor() {
  local s=" $1 "
  case "$s" in
    *" node-react "*)    echo "react" ;;
    *" node-vue "*)      echo "vue" ;;
    *" node-angular "*)  echo "angular" ;;
    *" node-svelte "*)   echo "svelte" ;;
    *" node-astro "*)    echo "astro" ;;
    *" node-solid "*)    echo "solid" ;;
    *" node-preact "*)   echo "preact" ;;
    *) echo "" ;;
  esac
}

# copy::supported_type <signals-string>
# Returns the install type (frontend / backend / base) for the detected stack,
# or "" / "ambiguous". Every detectable stack now resolves to a stack id with
# a matching stack-<id>.md addendum — the only ambiguity left is full-stack
# monorepos (Java + a Node frontend in the same dir).
copy::supported_type() {
  local s=" $1 "
  local has_be_java=0 has_fe=0
  case "$s" in *" java-spring "*) has_be_java=1 ;; esac
  case "$s" in
    *" node-react "*|*" node-vue "*|*" node-angular "*|*" node-svelte "*|\
*" node-astro "*|*" node-solid "*|*" node-preact "*) has_fe=1 ;;
  esac
  if [ "$has_be_java" = "1" ] && [ "$has_fe" = "1" ]; then
    echo "ambiguous"
    return
  fi
  # Single-stack case: look up the primary, then map to type.
  local stack
  stack="$(copy::primary_stack "$1")"
  if [ -n "$stack" ]; then
    copy::stack_to_type "$stack"
  else
    echo ""
  fi
}

# copy::unsupported_signals <signals-string>
# Returns signals for which there's no stack-<id>.md addendum at all. With the
# expanded coverage, this is now mostly empty (we have addendums for every
# detectable stack). Kept for forward compat — future detection additions
# without addendums would fall through here.
copy::unsupported_signals() {
  local out=()
  local s
  for s in $1; do
    case "$s" in
      # Frontend
      node-react|node-vue|node-angular|node-svelte|node-astro|node-solid|node-preact) : ;;
      # Backend (java-spring is the only Java signal stack_info emits)
      java-spring) : ;;
      node-nest|node-express|node-fastify|node-other) : ;;
      python-django|python-fastapi|python-flask|python-data|python-other) : ;;
      go|rust) : ;;
      ruby-rails|ruby-other) : ;;
      php-laravel|php-other) : ;;
      elixir-phoenix|elixir-other) : ;;
      dotnet-aspnet|dotnet-other) : ;;
      # Mobile
      flutter|swift-mobile|android-native|dart-pure) : ;;
      *) out+=("$s") ;;
    esac
  done
  echo "${out[*]:-}"
}

# copy::detect_main_branch <target_dir>
# Parses MAIN_BRANCH out of an existing pre-push (PROTECTED line). Falls back to
# `main`. Used by upgrade mode so the user doesn't have to retype it.
copy::detect_main_branch() {
  local target="$1"
  local f="$target/.husky/pre-push"
  [ -f "$f" ] || { echo "main"; return; }
  # Heuristic: PROTECTED='main master homolog staging develop <MAIN> <STAGING>'
  # The user-chosen MAIN is the 6th token; if absent or =main, default to main.
  local picked
  picked=$(grep -E "^PROTECTED=" "$f" | head -1 | sed -E "s/^PROTECTED='([^']*)'.*/\1/" | awk '{print $6}')
  [ -z "$picked" ] && picked="main"
  echo "$picked"
}

# copy::merge_file <src> <dest> [substitute=0|1] [strip_meta=0|1]
# Upgrade-mode file copy: if dest doesn't exist, copy + (optionally) substitute.
# If dest exists, prompt the user — overwrite (with .orig backup), skip, or
# show a diff first. User-config files (CLAUDE.md, naming.conf, settings.json,
# verify.sh) should NOT be passed here; they have dedicated handlers.
copy::merge_file() {
  local src="$1"
  local dest="$2"
  local substitute="${3:-0}"
  local strip_meta="${4:-0}"

  if [ ! -f "$dest" ]; then
    mkdir -p "$(dirname "$dest")"
    cp "$src" "$dest"
    [ "$substitute" = "1" ] && copy::substitute "$dest" "$strip_meta"
    ui::dim "  + $(basename "$dest")  (new)"
    return 0
  fi

  # Pre-substitute the source into a temp file so the diff/copy reflects the
  # final shape. Avoids "the diff is just placeholders" noise.
  local tmp
  tmp=$(mktemp 2>/dev/null \
        || mktemp -t icp.XXXXXX 2>/dev/null \
        || mktemp -p "${TMPDIR:-.}" icp.XXXXXX 2>/dev/null \
        || echo "${TMPDIR:-.}/icp.$$.tmp")
  cp "$src" "$tmp"
  [ "$substitute" = "1" ] && copy::substitute "$tmp" "$strip_meta"

  if cmp -s "$tmp" "$dest"; then
    rm -f "$tmp"
    ui::dim "  = $(basename "$dest")  (identical)"
    return 0
  fi

  # Conflict — interactive prompt loop.
  while :; do
    printf '%s%s%s exists and differs. [%so%sverwrite / %ss%skip / %sd%siff]: ' \
      "$C_BOLD" "$(basename "$dest")" "$C_RESET" \
      "$C_BOLD" "$C_RESET" "$C_BOLD" "$C_RESET" "$C_BOLD" "$C_RESET" >&2
    local reply=""
    if [ -r /dev/tty ]; then
      read -r reply </dev/tty || reply=""
    else
      read -r reply || reply=""
    fi
    case "${reply:-s}" in
      o|O)
        cp "$dest" "$dest.orig"
        cp "$tmp" "$dest"
        ui::ok "  + $(basename "$dest")  (overwritten — backup at $(basename "$dest").orig)"
        rm -f "$tmp"
        return 0
        ;;
      s|S|"")
        ui::dim "  ~ $(basename "$dest")  (skipped)"
        rm -f "$tmp"
        return 0
        ;;
      d|D)
        if command -v diff >/dev/null 2>&1; then
          diff -u "$dest" "$tmp" | head -200 || true
        else
          ui::warn "diff not available — install diffutils to use this option."
        fi
        ;;
      *) ui::warn "  unknown choice: $reply" ;;
    esac
  done
}

# copy::merge_settings_json <src_tmpl> <dest_json>
# Shallow JSON merge: keeps existing top-level keys, but replaces the entries in
# `hooks.<EVENT>` that point to scripts shipped by this template (matched by
# command path containing __PROJECT_ROOT__/scripts/<our-hook-script>.sh). User-
# defined hooks for those same events stay untouched.
copy::merge_settings_json() {
  local src="$1"
  local dest="$2"

  if [ ! -f "$dest" ]; then
    mkdir -p "$(dirname "$dest")"
    cp "$src" "$dest"
    copy::substitute "$dest" 1
    ui::dim "  + $(basename "$dest")  (new)"
    return 0
  fi

  # Pre-substitute the template so we merge the final shape.
  local tmp
  tmp=$(mktemp 2>/dev/null \
        || mktemp -t icp.XXXXXX 2>/dev/null \
        || mktemp -p "${TMPDIR:-.}" icp.XXXXXX 2>/dev/null \
        || echo "${TMPDIR:-.}/icp.$$.tmp")
  cp "$src" "$tmp"
  copy::substitute "$tmp" 1

  # Don't swallow Python errors — a malformed user settings.json should fail
  # loud, not silently leave the file untouched while we report success.
  local merge_rc=0
  PYICP_DEST="$dest" PYICP_TMPL="$tmp" "$(ui::python)" - <<'PY' || merge_rc=$?
import json, os
dest_path = os.environ["PYICP_DEST"]
tmpl_path = os.environ["PYICP_TMPL"]

OUR_SCRIPTS = (
    "hook-sessionstart.sh",
    "hook-prepush-validate.sh",
    "hook-stop-verify.sh",
)

def is_ours(cmd):
    return any(s in (cmd or "") for s in OUR_SCRIPTS)

with open(dest_path) as f:
    dest = json.load(f)
with open(tmpl_path) as f:
    tmpl = json.load(f)

dest.setdefault("hooks", {})
tmpl_hooks = tmpl.get("hooks", {}) or {}

for event, tmpl_groups in tmpl_hooks.items():
    dest_groups = dest["hooks"].get(event, []) or []
    # Strip our-managed hook entries; keep user-defined ones.
    cleaned = []
    for grp in dest_groups:
        kept = [h for h in grp.get("hooks", []) if not is_ours(h.get("command", ""))]
        if kept:
            grp = dict(grp); grp["hooks"] = kept
            cleaned.append(grp)
    # Append the template-managed groups (full replacement of OUR entries).
    cleaned.extend(tmpl_groups)
    dest["hooks"][event] = cleaned

with open(dest_path, "w") as f:
    json.dump(dest, f, indent=2, ensure_ascii=False)
    f.write("\n")
PY
  rm -f "$tmp"
  if [ "$merge_rc" -ne 0 ]; then
    ui::error "  ✗ $(basename "$dest")  (merge FAILED — Python error above; settings.json untouched)"
    ui::dim "    The existing file may be malformed JSON. Inspect $dest manually before re-running."
    return 1
  fi
  ui::ok "  + $(basename "$dest")  (merged: template hooks refreshed, user hooks preserved)"
}

# copy::husky <type> <target_dir>
# Copies husky/common/* + husky/<type>/*, substitutes placeholders in pre-push,
# and auto-wires core.hooksPath if target is already a git repo.
# In upgrade mode: per-file merge with prompt on conflict; naming.conf is
# treated as user-config (kept if it already exists, ENFORCE_* answers ignored).
copy::husky() {
  local type="$1"
  local target="$2"
  local src="$__ICP_COPY_ROOT/templates/husky"
  local mode="${ICP_MODE:-install}"

  mkdir -p "$target/.husky"

  if [ "$mode" = "upgrade" ]; then
    local f base
    if [ -d "$src/common" ]; then
      for f in "$src/common/"*; do
        base=$(basename "$f")
        if [ "$base" = "naming.conf" ] && [ -f "$target/.husky/naming.conf" ]; then
          ui::dim "  ~ .husky/naming.conf  (kept — naming convention is user-customizable)"
          continue
        fi
        copy::merge_file "$f" "$target/.husky/$base" 1 0
      done
    fi
    if [ -d "$src/$type" ]; then
      for f in "$src/$type/"*; do
        copy::merge_file "$f" "$target/.husky/$(basename "$f")" 1 0
      done
    fi
  else
    ui::info "Installing .husky/ (native git hooks, no npm dependency)"
    [ -d "$src/common" ] && cp -R "$src/common/." "$target/.husky/"
    [ -d "$src/$type" ]  && cp -R "$src/$type/."  "$target/.husky/"

    # pre-push has {{MAIN_BRANCH}}/{{STAGING_BRANCH}} in its PROTECTED list.
    [ -f "$target/.husky/pre-push" ] && copy::substitute "$target/.husky/pre-push" 0

    # naming.conf — apply per-check enable/disable based on installer answers.
    # Empty regex = check disabled (the hooks treat it as a no-op).
    if [ -f "$target/.husky/naming.conf" ]; then
      [ "${ENFORCE_COMMIT_MSG:-1}" = "0" ]  && copy::naming_disable "$target/.husky/naming.conf" COMMIT_MSG_REGEX
      [ "${ENFORCE_BRANCH_NAME:-1}" = "0" ] && copy::naming_disable "$target/.husky/naming.conf" BRANCH_NAME_REGEX
    fi
  fi

  find "$target/.husky" -type f ! -name '*.md' ! -name '*.conf' -exec chmod +x {} + 2>/dev/null || true

  # If target is the ROOT of a git repo (has .git as a dir or file), wire
  # core.hooksPath. Checking `[ -e "$target/.git" ]` avoids falsely picking up
  # a parent repo when $target is a subdirectory of an existing repo.
  if [ -e "$target/.git" ]; then
    git -C "$target" config core.hooksPath .husky
    ui::ok "Configured core.hooksPath=.husky in the existing git repo"
  fi
}

# copy::claude_settings <type> <target_dir>
# In upgrade mode: shallow JSON merge — refresh template-managed hook entries,
# preserve user-defined hooks for the same or other events.
copy::claude_settings() {
  local type="$1"
  local target="$2"
  local src="$__ICP_COPY_ROOT/templates/claude"
  local mode="${ICP_MODE:-install}"

  mkdir -p "$target/.claude"
  local tmpl="$src/settings.json.tmpl"
  [ -f "$src/$type/settings.json.tmpl" ] && tmpl="$src/$type/settings.json.tmpl"

  export PROJECT_ROOT
  PROJECT_ROOT="$(ui::abs_path "$target")"

  if [ "$mode" = "upgrade" ]; then
    copy::merge_settings_json "$tmpl" "$target/.claude/settings.json"
  else
    ui::info "Installing .claude/settings.json"
    cp "$tmpl" "$target/.claude/settings.json"
    copy::substitute "$target/.claude/settings.json" 1
  fi
}

# copy::root_files <target_dir>
# Copies files that live at target root (currently just .gitattributes).
# Skips existing files — doesn't overwrite user's own root config.
copy::root_files() {
  local target="$1"
  local src="$__ICP_COPY_ROOT/templates/root"
  [ -d "$src" ] || return 0
  ui::info "Installing root config files"
  local f name
  # shopt -s nullglob: unmatched patterns (e.g. no dotfiles) expand to nothing
  # instead of the literal string, which would then fall through and be caught
  # only by the [ -e ] guard. Enabled in a subshell to avoid leaking the option.
  (
    shopt -s nullglob
    for f in "$src"/* "$src"/.[!.]*; do
      name=$(basename "$f")
      if [ -e "$target/$name" ]; then
        ui::dim "  skip $name (already exists)"
        continue
      fi
      cp "$f" "$target/$name"
      ui::dim "  + $name"
    done
  )
}

# copy::gitignore <target_dir>
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
