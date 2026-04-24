# init-claude-project

Bootstrap a new project with opinionated Claude Code conventions — universal working principles, local-only gitflow, branch hygiene, testing discipline, and stack-specific tuning for frontend (React + Vite + Vitest) or backend (Java + Spring + Gradle + Testcontainers).

The workflow is **local-only**: it does NOT create PRs, merge branches, push to remote, or call any forge API (GitHub, GitLab, Azure DevOps, Bitbucket). Integration flow is your pipeline's responsibility — this toolkit just makes sure local discipline is tight so what you push is clean.

## Quick start

### One-liner (remote, via curl)

```bash
# Frontend
bash <(curl -fsSL https://raw.githubusercontent.com/ricardobpedro/init-claude-project/main/install.sh) frontend ./my-new-app

# Backend
bash <(curl -fsSL https://raw.githubusercontent.com/ricardobpedro/init-claude-project/main/install.sh) backend ./my-new-api
```

The bootstrap script clones the full toolkit to `~/.init-claude-project` (or updates an existing clone) and then runs the right entry point.

### Local (from a clone)

```bash
git clone https://github.com/ricardobpedro/init-claude-project.git
cd init-claude-project
./init-frontend.sh ./my-new-app      # or ./init-backend.sh ./my-new-api
```

## What gets installed

Into the target project directory:

- `CLAUDE.md` — universal working principles + gitflow + stack addendum (frontend or backend)
- `docs/troubleshooting.md` — recurring issues catalog (Windows Docker context, zombie Testcontainers, flaky schedulers, etc.)
- `scripts/branch-hygiene.sh` — detect stale / forgotten local branches (no forge API)
- `scripts/branch-start.sh` — safe branch creator (refuses to fork from stale main)
- `scripts/check-secrets.sh` — pre-push secret scan
- `scripts/test-backend.sh` — *(backend only)* gradle wrapper with Docker context fix for Windows
- `.husky/commit-msg` — conventional-commits enforcer
- `.husky/pre-push` — block direct push to protected branches + run check-secrets
- `.husky/pre-commit` — lint-staged (frontend) or spotless check (backend)
- `.claude/settings.json` — SessionStart hook (branch-hygiene) + PreToolUse Bash hook (block push + secrets)
- `.gitattributes` — pin LF for `.sh`, `.bash`, `.husky/*` (avoids Windows CRLF breakage)
- `.gitignore` — appended entries for `.claude/settings.local.json`, `.remember/`, `docs/scrum/`

Into `~/.claude/projects/<hashed-project-path>/memory/`:

- 6 universal feedback memories (branch hygiene, coverage ratchet, Opus for audits, docs-with-code, Claude config authorization, global vs project skills)
- 1 reference memory (testing standard pointer)
- `MEMORY.md` index

## Preflight

Before installing, the script validates:

**Tools (required):**
- `git` — hard prerequisite (no autoinstall; [install guide](https://git-scm.com/downloads))
- `bash` — Git Bash on Windows, native on Linux/macOS
- `jq` — JSON parsing (autoinstalled via apt/dnf/pacman/brew/winget/scoop)
- `python3` — used by hook commands to JSON-encode output
- `node` + `npm` — frontend only
- `java` — backend only (manual install; [Temurin](https://adoptium.net/))
- `claude` — Claude Code CLI (autoinstalled via `npm install -g @anthropic-ai/claude-code`)

**Tools (optional):**
- `docker` — backend only, needed for Testcontainers + compose

**Claude Code globals (warn-only, non-fatal):**
- `~/.claude/CLAUDE.md`, `~/.claude/settings.json` — required
- `~/.claude/agents/audit-*` (10 agents) — recommended
- Enabled plugins: `superpowers`, `code-review`, `feature-dev`, `pr-review-toolkit`, `claude-md-management`, `commit-commands`, `remember`

Missing required tools trigger an interactive autoinstall prompt (with the exact command shown). Declining cancels the install.

## Directory layout

```
init-claude-project/
├── README.md                          this file
├── install.sh                         one-liner bootstrap + local dispatcher
├── init-frontend.sh                   entry point — frontend projects
├── init-backend.sh                    entry point — backend projects
├── preflight-manifest.json            tool + globals manifest (edit to customize)
├── lib/
│   ├── ui.sh                          colored output + prompts + OS detection
│   ├── preflight.sh                   validation + autoinstall
│   └── copy.sh                        file operations + placeholder substitution
├── md_sources/                        REVIEWABLE — all markdown copied/merged by the installer
│   ├── CLAUDE/
│   │   ├── base.md                    universal skeleton
│   │   ├── frontend.md                frontend addendum
│   │   └── backend.md                 backend addendum
│   ├── docs/
│   │   └── troubleshooting.md         recurring-issue catalog
│   └── memory-seeds/
│       ├── MEMORY.md                  index
│       ├── feedback_*.md              6 universal feedback memories
│       └── reference_*.md             1 reference memory
└── templates/                         non-md files (scripts, hooks, settings, gitattributes)
    ├── root/                          files that land at project root
    │   └── .gitattributes
    ├── scripts/
    │   ├── common/                    branch-hygiene.sh, branch-start.sh, check-secrets.sh
    │   ├── frontend/                  (empty for now)
    │   └── backend/                   test-backend.sh
    ├── husky/
    │   ├── common/                    commit-msg, pre-push
    │   ├── frontend/                  pre-commit (lint-staged)
    │   └── backend/                   pre-commit (spotless check)
    └── claude/
        └── settings.json.tmpl         __PROJECT_ROOT__ substituted at install
```

## Local-only gitflow

This toolkit ONLY enforces local discipline:

1. Every new branch starts from an up-to-date `main` (use `scripts/branch-start.sh`).
2. Branch naming: `feat/`, `fix/`, `refactor/`, `chore/`, `test/`, `docs/`, `perf/`, `style/`.
3. Protected branches (`main`, `master`, `homolog`, `staging`, `develop`) can't be pushed to directly — Husky `pre-push` blocks it.
4. Commit messages follow Conventional Commits — enforced by Husky `commit-msg`.
5. `scripts/branch-hygiene.sh` runs at session start (via Claude Code SessionStart hook) and flags stale / forked-from-outdated branches.

It does NOT:
- Create PRs
- Merge branches
- Push to remote automatically
- Query GitHub, GitLab, Azure DevOps, or any forge API

Push, PR, merge, and pipeline triggering are **manual user actions** or pipeline responsibilities.

## Placeholders substituted at install time

In any file copied to the target:

| Placeholder | Source | Default |
|---|---|---|
| `{{PROJECT_SUMMARY}}` | Prompted at install | *(empty — must be provided)* |
| `{{MAIN_BRANCH}}` | Prompted at install | `main` |
| `{{STAGING_BRANCH}}` | Prompted at install | *(empty — optional)* |
| `__PROJECT_ROOT__` | Absolute target path | *(computed)* |

The ticket prefix for TODOs (`// TODO [US-NNN]: ...`) is baked as `US`. Change it in the generated `CLAUDE.md` if your tracker uses a different prefix.

## What's NOT included (by design)

- GitHub integration (`gh` CLI, PR templates, CODEOWNERS)
- Merge / PR workflow
- CI / CD workflow files
- Scrum folder committed to git (`docs/scrum/` is gitignored — real tracker lives in Azure DevOps or equivalent)
- Feature-inventory maintenance discipline (opt-in via manual addendum)
- Domain-specific skills (LGPD/BR, Asaas, WhatsApp — install manually from global `~/.claude/skills/` if relevant)

## Updating the toolkit

When the toolkit evolves:

```bash
cd ~/.init-claude-project   # or wherever you cloned
git pull
```

Subsequent runs of `install.sh` use the updated version. Existing target projects are NOT retroactively updated — re-run the installer if you want to refresh.

## Extending

All markdown lives in `md_sources/` — edit it directly, commit, and new projects will pick up the changes. Likewise for `templates/`. The preflight manifest is JSON — add tools or globals without touching the shell logic.

## License

Use it, fork it, adapt it. No warranty.
