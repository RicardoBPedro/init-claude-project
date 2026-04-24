# CLAUDE.md

<!--
  Universal skeleton. Concatenated with stack addendums (frontend.md /
  backend.md) and opted-in addendums (brazil, mutation-*) at install time.

  Placeholders substituted by the installer:
    {{PROJECT_SUMMARY}}  — one-liner, e.g. "TypeScript frontend project."
    {{MAIN_BRANCH}}      — main / master (default: main)
    {{STAGING_BRANCH}}   — homolog / staging / uat (optional; installer may omit)
  Fixed default (no prompt): ticket prefix `US` (change below if your tracker uses JIRA/LIN/GH/etc).
-->

{{PROJECT_SUMMARY}}

For any fix/feature, check if multiple layers/modules are affected and implement all.

Prefer incremental changes. For architecture shifts, propose the minimal-change option first and let the user decide scope.

## Working principles

These four principles govern every change. They take precedence over speed, completeness, or convenience — when in doubt, apply them.

### 1. Think before coding

Don't assume. Don't hide confusion. Surface tradeoffs.

Before implementing: state assumptions (ask if uncertain); if multiple interpretations exist, present them instead of picking silently; flag simpler approaches and push back when warranted; stop and name what's confusing when unclear.

### 2. Simplicity first

Minimum code that solves the problem. Nothing speculative: no features beyond what was asked, no abstractions for single-use code, no unrequested flexibility/configurability, no error handling for impossible scenarios. If 200 lines could be 50, rewrite.

Senior-engineer heuristic: *"Would they call this overcomplicated?"* If yes, simplify.

### 3. Surgical changes

Touch only what you must. Clean up only your own mess.

Editing existing code: don't "improve" adjacent code/comments/formatting; don't refactor what isn't broken; match existing style; mention unrelated dead code without deleting. Remove only the imports/variables/functions that YOUR edit made unused — leave pre-existing dead code alone unless asked.

**Test:** every changed line traces directly to the user's request.

**When repo rules conflict:** apply the narrowest change satisfying the higher-priority rule in scope. If the tradeoff is ambiguous, surface it — don't choose silently.

### 4. Goal-driven execution

Define success criteria. Loop until verified.

Transform tasks into verifiable goals: *"Add validation"* → *"Write tests for invalid inputs, then make them pass"*; *"Fix the bug"* → *"Write a test that reproduces it, then make it pass"*; *"Refactor X"* → *"Tests pass before and after"*.

For multi-step tasks, state a brief plan:

```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
```

Strong success criteria let you loop independently; weak ones (*"make it work"*) need constant clarification.

**Approval gates override the loop.** Autonomous looping applies to *verification* (run tests, fix, re-run), not to *scope/strategy*. Risky or irreversible actions — destructive ops, force-push, deleting shared state — always require explicit user consent, even in auto mode.

## Gitflow (local-only workflow)

Local discipline only. Integration (merges to `develop` / `{{STAGING_BRANCH}}` / `{{MAIN_BRANCH}}`, PR creation, CI/CD) is the project's pipeline — not this workflow.

**Enforced locally:**
1. New branches start from **up-to-date `{{MAIN_BRANCH}}`** — never from another feature branch or stale local main.
2. Branch naming: `feat/`, `fix/`, `refactor/`, `chore/`, `test/`, `docs/`, `perf/`, `style/`.
3. Protected branches (`{{MAIN_BRANCH}}`, `{{STAGING_BRANCH}}`, `develop`) are push-blocked by Husky.
4. Commit messages follow Conventional Commits (Husky `commit-msg` enforces).
5. CLAUDE.md rules (simplicity, surgical, TODO budget, testing discipline) validated before commit.

**NOT done here:** no PR creation, no merges, no automatic push, no forge API calls (GitHub / GitLab / Azure DevOps / Bitbucket), no automated network. `git fetch` / `git push` happen only on explicit user action or via `scripts/branch-start.sh`. Push / PR / merge / pipeline triggering are manual or pipeline responsibility.

### Starting a new branch

```bash
git fetch origin
git checkout {{MAIN_BRANCH}}
git pull --ff-only
git checkout -b feat/<short-description>
```

`scripts/branch-start.sh <type>/<slug>` automates the safe path — refuses to branch if `{{MAIN_BRANCH}}` is behind upstream or dirty.

### Branch hygiene (NON-NEGOTIABLE)

Stale branches are the main local failure mode. Run `scripts/branch-hygiene.sh` at session start and before handoff — strictly local (no `git fetch`, no forge API, no `origin/*` inspection), works offline. Reports:
- Age > `STALE_DAYS` (default 7) — review, rebase, or delete.
- Merge-base with `{{MAIN_BRANCH}}` older than `STALE_BASE_DAYS` (default 30) — likely forked from outdated state.
- Forked from something other than `{{MAIN_BRANCH}}` (e.g. `develop`) — violates the "branch from main" rule (`scripts/branch-start.sh` prevents this at creation).

Override: `STALE_DAYS=14 bash scripts/branch-hygiene.sh`.

**Resolving a stale branch:** never delete silently. Show scope (commits, diff vs `{{MAIN_BRANCH}}`, merge-base age) and let the user choose: rebase, cherry-pick, push, or abandon. Lost work is worse than a messy merge.

## Commit Convention

Conventional commits: `feat:`, `fix:`, `refactor:`, `test:`, `docs:`, `chore:`, `style:`, `perf:`. Scope when relevant (`feat(auth): ...`). Subject under 72 chars, Portuguese PT-br. Husky `commit-msg` enforces.

## TODO budget

New `TODO` / `FIXME` MUST reference a ticket on the same line:

```
// TODO [US-NNN]: ...
// FIXME [US-NNN]: ...
```

Prefix defaults to `US`; change to your tracker (`JIRA`, `LIN`, `GH`, etc.). Un-IDed = unscheduled work = forbidden — open the ticket or delete the comment now. When editing near an existing un-IDed TODO, prefer attaching an ID or deleting over leaving it untouched.

## Scrum local context

`docs/scrum/` is **gitignored**. Real tracker is Azure DevOps (or your team's tracker); this folder exists so Claude keeps context between sessions when drafting stories/tasks/plans.

Layout Claude drafts into:
- `docs/scrum/epics/EP-NNN-<slug>.md`
- `docs/scrum/stories/EP-NNN/US-NNN-<slug>.md`
- `docs/scrum/tasks/US-NNN/TASK-NNN-<slug>.md`

When approved, copy to the real tracker manually. Don't commit `docs/scrum/` — it drifts from the tracker immediately. Templates: `docs/scrum/TEMPLATES.md`.

## Pull Request convention

PRs are created manually. PR body structure: **Summary** (link tracking ticket) → **Changes by layer** → **How to test** → **Breaking changes** → **References**.

## Definition of Done

Before declaring a change done:

1. Static analysis / typecheck — zero errors
2. Tests — zero failures
3. Lint — zero errors
4. UI changes: themes + viewports verified (if applicable)
5. API changes: consumers updated
6. New features: at least one happy-path test

Stack-specific DoD extensions live in the addendum.

## Testing discipline

**Project-specific idioms** (if present): `docs/development/testing-standard.md`.

**Six principles** (ranked — top wins):
1. Tests guarantee a business rule — coverage is a signal, not a goal.
2. Pick the lightest layer where the rule *reads* naturally. Unit > slice > integration.
3. Slow tests only for emergent behaviour — integration has a budget. Full-stack (Testcontainers, `@SpringBootTest`, Cypress, Playwright) = last resort, not default.
4. Skip rare + complex scenarios unless the failure is catastrophic (financial / security / data integrity → test anyway).
5. Test behaviour, not implementation. Mocks on boundaries, not on internal methods.
6. Every bug fix ships with a regression test that fails on the old code.

**Zero-tolerance:** flaky = broken (diagnose or delete, never retry); time/randomness/IO must be injectable; coverage threshold is a ratchet (up only).

## Workflow skills/agents

From **public Claude Code plugins** — preflight warns if a plugin isn't enabled in `~/.claude/settings.json`. Nothing here is bundled.

- Bug investigation → `systematic-debugging` skill (plugin: `superpowers`). Reproduce → isolate → diagnose → fix → verify. Never guess.
- Post-feature review → `feature-dev:code-reviewer` agent (plugin: `feature-dev`) or `/review-pr` (plugin: `pr-review-toolkit`). Run before declaring done.
- Plan before coding → `writing-plans` skill (plugin: `superpowers`) for multi-step tasks.
- Execute plans with checkpoints → `executing-plans` skill (plugin: `superpowers`).

**Project-authored skills/agents** (if your project has `.claude/skills/` or `.claude/agents/`): reference by name here. Examples you might wire up:
- Post-mortem skill (produces `docs/bmad/rca/YYYY-MM-DD-<slug>.md` after a real bug fix)
- Critical-path edge-case hunter for financial / auth / state-machine diffs
- Pre-push quality gate agent invoked by `.claude/settings.json` PreToolUse

The installer does NOT ship these.

## Troubleshooting

`docs/troubleshooting.md` catalogs recurring blockers (Docker context on Windows, killed test runs leaving zombie containers, etc.). Check it before filing a "works on my machine" bug.

## Architecture

Codebase map in `docs/architecture.md` (if present). Session state buffers in `.remember/now.md`. CLAUDE.md is a map of rules and commands, not a manual — use `grep` / `git log` to discover specifics.
