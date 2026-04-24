# CLAUDE.md

<!--
  Universal skeleton. This file is concatenated with stack addendums
  (frontend.md / backend.md) and any opted-in addendums (brazil)
  at install time to produce the final <project>/CLAUDE.md.

  Placeholders substituted by the installer:
    {{PROJECT_SUMMARY}}  — one-liner, e.g. "TypeScript frontend project."
    {{MAIN_BRANCH}}      — main / master (default: main)
    {{STAGING_BRANCH}}   — homolog / staging / uat (optional; installer may omit)
  Fixed defaults (no prompt):
    ticket prefix        — US  (update below if the team uses JIRA/LIN/GH/etc.)
-->

{{PROJECT_SUMMARY}}

For any fix/feature, check if multiple layers/modules are affected and implement all.

Prefer incremental, conservative changes. When proposing architecture shifts, present the minimal-change option first and let the user decide scope.

## Working principles

These four principles govern every change in this repo. They take precedence over speed, completeness, or convenience — when in doubt, apply them.

### 1. Think before coding

Don't assume. Don't hide confusion. Surface tradeoffs.

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them — don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

### 2. Simplicity first

Minimum code that solves the problem. Nothing speculative.

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: *"Would a senior engineer say this is overcomplicated?"* If yes, simplify.

### 3. Surgical changes

Touch only what you must. Clean up only your own mess.

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it — don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

**The test:** every changed line should trace directly to the user's request.

**Judgment call when repo rules conflict.** Apply the narrowest change that still satisfies the higher-priority repo rule in scope. If the tradeoff is ambiguous, surface it to the user instead of choosing silently.

### 4. Goal-driven execution

Define success criteria. Loop until verified.

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:

```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

**Approval gates override the loop.** Autonomous looping applies to *verification* (run tests, fix, re-run), not to *scope/strategy*. Risky or irreversible actions — destructive ops, force-push, deleting shared state — always require explicit user consent, even in auto mode.

## Gitflow (local-only workflow)

This Claude workflow controls **local discipline only**. Integration flow (merges to `develop` / `{{STAGING_BRANCH}}` / `{{MAIN_BRANCH}}`, PR creation, CI/CD) is handled by the project's own pipeline — not by this workflow.

**What this workflow enforces locally:**
1. Every new branch is created from an **up-to-date `{{MAIN_BRANCH}}`** — never from another feature branch, never from a stale local main.
2. Branch naming: `feat/`, `fix/`, `refactor/`, `chore/`, `test/`, `docs/`, `perf/`, `style/`.
3. Protected branches (`{{MAIN_BRANCH}}`, `{{STAGING_BRANCH}}`, `develop`) cannot be pushed to directly. Husky blocks the push.
4. Commit messages follow Conventional Commits (enforced by Husky `commit-msg`).
5. Claude rules in this file (simplicity, surgical, TODO budget, testing discipline) are validated before commits.

**What this workflow does NOT do:**
- Create PRs
- Merge branches
- Push to remote automatically
- Interact with any forge (GitHub / GitLab / Azure DevOps / Bitbucket) — no PR / issue / merge API calls
- Make automated network calls — hygiene scripts are strictly local. `git fetch` / `git push` happen only when the user invokes them or runs `scripts/branch-start.sh` explicitly.

Push, PR, merge, and pipeline triggering are **manual user actions** or pipeline responsibilities.

### Starting a new branch

```bash
git fetch origin
git checkout {{MAIN_BRANCH}}
git pull --ff-only
git checkout -b feat/<short-description>
```

`scripts/branch-start.sh <type>/<slug>` automates the safe path — it refuses to branch if the current `{{MAIN_BRANCH}}` is behind its upstream or dirty.

### Branch hygiene (NON-NEGOTIABLE)

Stale / forgotten branches are the main local failure mode. Run `scripts/branch-hygiene.sh` at session start and before handoff. It is **strictly local** — no `git fetch`, no forge API calls, no inspection of `origin/*` refs — so it works offline and never waits on the network. Reports:
- Branches older than `STALE_DAYS` (default 7) — review, rebase, or delete.
- Branches whose merge-base with `{{MAIN_BRANCH}}` is older than `STALE_BASE_DAYS` (default 30) — likely forked from outdated state.
- Branches forked from something other than `{{MAIN_BRANCH}}` (e.g. `develop`) — violates the "branch from main" rule (`scripts/branch-start.sh` prevents this at creation time).

Bump thresholds per invocation: `STALE_DAYS=14 bash scripts/branch-hygiene.sh`.

**When resolving a stale branch:** do NOT quietly delete it. Present the user with its scope (commit list, file diff vs `{{MAIN_BRANCH}}`, merge-base age) and let them choose: rebase, cherry-pick, push, or abandon. Lost work is worse than a messy merge.

## Commit Convention

Conventional commits: `feat:`, `fix:`, `refactor:`, `test:`, `docs:`, `chore:`, `style:`, `perf:`. Scope when relevant (`feat(auth): ...`). Subject under 72 chars, Portuguese PT-br. Husky `commit-msg` enforces.

## TODO budget

New `TODO` / `FIXME` comments MUST reference a ticket ID in the same line:

```
// TODO [US-NNN]: ...
// FIXME [US-NNN]: ...
```

Use the ticket prefix your team uses in its tracker (default here is `US`; change to `JIRA`, `LIN`, `GH`, etc. as needed). Un-IDed TODOs accumulate faster than they get closed — a `TODO` without an ID is by definition unscheduled work, so force the author to either open the ticket or delete the comment now.

When you encounter an existing un-IDed TODO while editing nearby code, prefer closing it or attaching an ID over leaving it untouched.

## Scrum local context

`docs/scrum/` is **gitignored**. The real tracker lives in Azure DevOps (or your team's tracker); this folder exists only so Claude Code keeps context between sessions when drafting stories, tasks, or plans.

Typical layout Claude drafts into:
- `docs/scrum/epics/EP-NNN-<slug>.md`
- `docs/scrum/stories/EP-NNN/US-NNN-<slug>.md`
- `docs/scrum/tasks/US-NNN/TASK-NNN-<slug>.md`

When a draft is approved, copy the relevant parts into the real tracker manually. Don't commit `docs/scrum/` — it would drift from the tracker immediately.

Templates: `docs/scrum/TEMPLATES.md`.

## Pull Request convention

PRs are created manually by the user. When drafting a PR body, follow this structure:

**Summary** (link tracking ticket) → **Changes by layer** → **How to test** → **Breaking changes** → **References**.

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

**Six principles** (summary below; same as any good testing standard):
1. Tests exist to guarantee a business rule still holds — coverage is a signal, not a goal.
2. Pick the lightest layer where the rule *reads* naturally. Unit > slice > integration.
3. Slow tests only for emergent behaviour — integration has a budget. Full-stack tests (Testcontainers, `@SpringBootTest`, Cypress, Playwright) are last resort, not default.
4. Skip rare + complex scenarios unless the failure is catastrophic (financial / security / data integrity → test it anyway).
5. Test behaviour, not implementation — mocks on boundaries, not on internal method calls.
6. Every bug fix ships with a regression test that fails on the old code.

**Zero-tolerance rules:** flaky = broken (diagnose or delete, never retry); time/randomness/IO must be injectable; coverage threshold is a ratchet (up only).

## Workflow skills/agents

These come from **public Claude Code plugins** — preflight warns if the plugin isn't enabled in `~/.claude/settings.json`. Nothing here is bundled with this toolkit; it's all external.

- **Bug investigation** → `systematic-debugging` skill (plugin: `superpowers`). Reproduce → isolate → diagnose → fix → verify. Never guess.
- **Post-feature review** → `feature-dev:code-reviewer` agent (plugin: `feature-dev`) or `/review-pr` command (plugin: `pr-review-toolkit`). Run before declaring done.
- **Plan before coding** → `writing-plans` skill (plugin: `superpowers`) for multi-step tasks.
- **Execute plans with checkpoints** → `executing-plans` skill (plugin: `superpowers`).

**Project-authored skills / agents** (if your project has `.claude/skills/` or `.claude/agents/`): reference them by name here. Common examples you may wire up yourself:
- A post-mortem skill (produces `docs/bmad/rca/YYYY-MM-DD-<slug>.md` after a real bug fix)
- A critical-path edge-case hunter for financial / auth / state-machine diffs
- A pre-push quality gate agent invoked by the `.claude/settings.json` PreToolUse hook

The installer does NOT ship these — they're per-project authoring. Add them as you grow.

## Troubleshooting

`docs/troubleshooting.md` catalogs the recurring issues that block development (Docker context on Windows, killed test runs leaving zombie containers, etc.). Check it before filing a "works on my machine" bug.

## Architecture

Codebase map in `docs/architecture.md` (if the project has it). Session state buffers in `.remember/now.md`. CLAUDE.md is a map of rules and commands, not a manual — use `grep` / `git log` to discover specifics.
