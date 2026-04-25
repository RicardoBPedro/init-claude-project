# init-claude-project

Opinionated bootstrap for projects that use [Claude Code](https://claude.com/claude-code). Installs working principles, a local-only gitflow, branch / commit hygiene, a quality-gate harness, and a stack-aware `CLAUDE.md` tuned to the project at hand.

**Scope is local only.** The toolkit does not push, open PRs, merge branches, or call any forge API — that is your pipeline's job.

## Quick start

The toolkit is bash-based — on Windows use **Git Bash** (ships with [Git for Windows](https://git-scm.com/downloads)) or **WSL**.

**Linux / macOS / Git Bash / WSL:**

```bash
# Remote (no clone needed)
bash <(curl -fsSL https://raw.githubusercontent.com/RicardoBPedro/init-claude-project/main/install.sh) ./my-project

# Local (from a clone)
./install.sh ./my-project

# Pin a version
ICP_REPO_REF=v1.0.0 bash <(curl -fsSL .../install.sh) ./my-project
```

**Windows PowerShell** (requires bash on PATH — Git for Windows or WSL):

```powershell
# Remote
curl.exe -fsSL https://raw.githubusercontent.com/RicardoBPedro/init-claude-project/main/install.sh | bash -s -- ./my-project

# Pin a version
$env:ICP_REPO_REF="v1.0.0"; curl.exe -fsSL https://raw.githubusercontent.com/RicardoBPedro/init-claude-project/main/install.sh | bash -s -- ./my-project
```

> PowerShell aliases `curl` to `Invoke-WebRequest` (different syntax), so use `curl.exe` to hit the real binary. Process substitution `<(...)` doesn't exist in PowerShell — pipe through `bash -s --` instead.

`install.sh` is the single entry point. It auto-detects the stack and whether to run a fresh install or refresh an existing one — re-running the same command months later lands in upgrade mode automatically. Run with `--help` for overrides.

## Supported stacks

Each stack ships its own `CLAUDE.md` addendum with idiomatic patterns, anti-patterns, canonical commands and gotchas.

<details>
<summary><b>25 stacks with dedicated addendums</b></summary>

**Frontend** — React / Next / Remix / Gatsby · Vue / Nuxt · Angular · Svelte / SvelteKit · Astro · SolidJS · Preact

**Backend (JVM)** — Java + Spring (Gradle / Maven)

**Backend (Node)** — NestJS · Fastify · Express · Koa / Hapi / Hono / Elysia

**Backend (Python)** — Django · FastAPI · Flask · NumPy / Pandas

**Backend (other)** — Go · Rust · Ruby on Rails · PHP / Laravel · Elixir / Phoenix · .NET / ASP.NET Core

**Mobile** — Flutter · Swift (iOS) · Kotlin (Android)

</details>

If no signal matches, the installer falls back to a `base` install — universal scaffolding without a stack-specific addendum.

## What you get

- `CLAUDE.md` with universal principles + gitflow + your stack's addendum
- Native git hooks (`core.hooksPath=.husky`, no `husky` npm dep) wiring commit-msg, pre-commit, pre-push
- Quality-gate skeleton (`scripts/verify.sh`) wired to a Stop hook so Claude can't declare "done" with a broken tree
- Branch hygiene + secret scan + protected-branch push block
- Project-local Claude memory seeds, activated on demand
- `docs/troubleshooting.md` with recurring-issue catalog (Windows Docker, Testcontainers, …)

## Commit / branch convention

Edit `.husky/naming.conf` — sourced by every hook run, no rebuild needed. Empty any `*_REGEX` to disable that check (the protected-branch push-block stays on regardless).

Defaults:

| | Format | Example |
|---|---|---|
| Commit | `[<TYPE>]#<task>: <description>` | `[FEATURE]#12345: add refresh token rotation` |
| Branch | `<type>/<card-number>/<slug>` | `feature/12345/login-redirect` |

Conventional Commits and Jira-tagged presets ship commented inside the file — paste over the defaults to switch.

## Local-only gitflow

1. New branches start from an up-to-date `main` (`scripts/branch-start.sh`).
2. Protected branches (`main`, `master`, `homolog`, `staging`, `develop`) cannot be pushed to directly.
3. `scripts/branch-hygiene.sh` runs at session start and flags stale branches.

Push, PR, merge and pipeline triggering remain manual / pipeline responsibilities.

## Requirements

`git`, `bash`, `jq`, `python3`, plus `node`+`npm` (frontend) or `java` (backend). Missing tools trigger an interactive autoinstall prompt. Full manifest in [`preflight-manifest.json`](preflight-manifest.json).

## Layout

```
init-claude-project/
├── install.sh           single entry point (auto-detects stack + mode)
├── init-*.sh            direct entry points for scripted setups
├── lib/                 ui, preflight, copy primitives
├── md_sources/          all markdown copied/merged into target projects
└── templates/           non-md assets (scripts, hooks, settings)
```

## License

Use it, fork it, adapt it. No warranty.
