# CLAUDE.md

<!--
  Universal skeleton. Concatenated with stack addendum (stack-*.md) and opted-in
  addendums (brazil, mutation-*) at install time.

  Placeholders substituted by the installer:
    {{PROJECT_SUMMARY}}  — one-liner, e.g. "TypeScript frontend project."
    {{MAIN_BRANCH}}      — main / master (default: main)
    {{STAGING_BRANCH}}   — homolog / staging / uat (optional)
  Fixed default: ticket prefix `US` (change inline if your tracker uses JIRA/LIN/GH).
-->

{{PROJECT_SUMMARY}}

For any fix/feature, check all affected layers/modules and implement them. Prefer incremental changes; for architecture shifts, propose the minimal-change option first.

## Working principles

Four principles that take precedence over speed/completeness/convenience.

### 1. Think before coding

State assumptions; ask if uncertain. If multiple interpretations exist, present them — don't pick silently. Flag simpler approaches. Stop and name what's confusing.

### 2. Simplicity first

Minimum code that solves the problem. No speculative features, no abstractions for single-use code, no unrequested flexibility, no error handling for impossible scenarios. If 200 lines could be 50, rewrite. Senior-engineer test: *"Would they call this overcomplicated?"*

### 3. Surgical changes

Touch only what you must. Don't "improve" adjacent code/comments/formatting; don't refactor what isn't broken; match existing style. Remove only the imports/variables your edit made unused. Every changed line traces directly to the user's request.

**When repo rules conflict:** apply the narrowest change satisfying the higher-priority rule. If ambiguous, surface it — don't choose silently.

### 4. Goal-driven execution

Define success criteria, loop until verified.

Transform tasks into verifiable goals: *"Add validation"* → *"Tests for invalid inputs pass"*; *"Fix the bug"* → *"Regression test reproduces it, then passes"*; *"Refactor X"* → *"Tests pass before and after"*.

For multi-step tasks, state a brief plan: `1. [Step] → verify: [check]`.

**Approval gates override the loop.** Autonomous looping applies to *verification*, not *scope/strategy*. Destructive ops, force-push, deleting shared state — always require explicit consent.

### Quality gate (auto-verify on Stop)

A Stop hook runs `scripts/verify.sh` whenever the working tree differs from HEAD. Failures block "done" — load-bearing for bug fixes (regression test must run after the fix).

- **Customize:** edit `scripts/verify.sh` for your project (lint, typecheck, compile, fast unit tests). Default is fast-only — full suites stay manual / pre-push.
- **Disable temporarily:** `touch .claude/verify.disabled`.
- **Performance:** keep under ~30s. Slow gates train everyone to ignore them.

## Gitflow (local-only workflow)

Local discipline only. Integration (merges to `develop` / `{{STAGING_BRANCH}}` / `{{MAIN_BRANCH}}`, PRs, CI/CD) is the project's pipeline.

**Enforced locally:**
1. New branches start from up-to-date `{{MAIN_BRANCH}}` — never from another feature branch or stale local main.
2. Branch + commit format configurable per project in `.husky/naming.conf`. Defaults: branch `<type>/<card>/<slug>` (`feature|bugfix|hotfix|refact|test|docs|chore|style|perf|ci|build|revert`); commit `[<TYPE>]#<taskNumber>: <description>`. Empty regex = check disabled.
3. Protected branches (`{{MAIN_BRANCH}}`, `{{STAGING_BRANCH}}`, `develop`) push-blocked by Husky — always on, independent of `naming.conf`.
4. CLAUDE.md rules validated before commit.

**NOT done here:** no PR creation, no merges, no automatic push, no forge API calls. `git fetch` / `git push` happen only on explicit user action or `scripts/branch-start.sh`.

### Starting a new branch

```bash
git fetch origin && git checkout {{MAIN_BRANCH}} && git pull --ff-only
git checkout -b feature/<card-number>/<short-description>
```

`scripts/branch-start.sh <type>/<card>/<slug>` automates this — refuses if `{{MAIN_BRANCH}}` is behind upstream or dirty.

### Branch hygiene (NON-NEGOTIABLE)

Stale branches are the main local failure mode. Run `scripts/branch-hygiene.sh` at session start and before handoff (strictly local, works offline). Reports:
- Age > `STALE_DAYS` (default 14 — covers a 2-week sprint) — review, rebase, or delete.
- Merge-base with `{{MAIN_BRANCH}}` older than `STALE_BASE_DAYS` (default 30) — likely forked from outdated state.
- Forked from non-`{{MAIN_BRANCH}}` (e.g. `develop`) — violates "branch from main".

Override: `STALE_DAYS=21 bash scripts/branch-hygiene.sh`.

**Resolving stale branches:** never delete silently. Show scope (commits, diff, merge-base age) and let the user choose: rebase, cherry-pick, push, or abandon.

## Commit Convention

Default: `[<TYPE>]#<taskNumber>: <description>` — e.g. `[FEATURE]#12345: add refresh token rotation`. Subject ≤72 chars, PT-br. Edit `.husky/naming.conf` to swap presets (Conventional Commits, Jira-tagged, custom) or disable.

## TODO budget

New `TODO`/`FIXME` MUST reference a ticket on the same line: `// TODO [US-NNN]: ...`. Un-IDed = forbidden — open the ticket or delete the comment now. Prefix defaults to `US`; change to your tracker (`JIRA`, `LIN`, `GH`).

## Scrum local context

`docs/scrum/` is **gitignored** — exists so Claude keeps context between sessions when drafting stories/tasks/plans. Real tracker is your team's (Azure DevOps, Jira, Linear).

Layout:
- `docs/scrum/epics/EP-NNN-<slug>.md`
- `docs/scrum/stories/EP-NNN/US-NNN-<slug>.md`
- `docs/scrum/tasks/US-NNN/TASK-NNN-<slug>.md`

Templates: `docs/scrum/TEMPLATES.md`. When approved, copy to the real tracker manually — `docs/scrum/` drifts immediately.

## Pull Request convention

PRs created manually. Body: **Summary** (link ticket) → **Changes by layer** → **How to test** → **Breaking changes** → **References**.

## Definition of Done

1. Static analysis / typecheck — zero errors
2. Tests — zero failures
3. Lint — zero errors
4. UI changes: themes + viewports verified
5. API changes: consumers updated
6. New features: at least one happy-path test
7. Trade-off decisions: ADR written before claiming done

Stack-specific DoD extensions live in the stack addendum.

## Decision log

Trade-off decisions (architecture pivots, library swaps, contract changes) → ADR at `docs/decisions/<YYYY-MM-DD>-<slug>.md` before declaring done. Skip trivial bugs and mechanical refactors.

## Testing discipline

**Project-specific idioms:** `docs/development/testing-standard.md` (if present).

**Six principles** (top wins):
1. Tests guarantee a business rule — coverage is a signal, not a goal.
2. Pick the lightest layer where the rule reads naturally. Unit > slice > integration.
3. Slow tests have a budget. Full-stack (Testcontainers, `@SpringBootTest`, Cypress, Playwright) = last resort.
4. Skip rare + complex scenarios unless failure is catastrophic (financial / security / data integrity → test).
5. Test behaviour, not implementation. Mocks on boundaries, not internal methods.
6. Every bug fix ships with a regression test that fails on the old code.

**Zero-tolerance:** flaky = broken (diagnose or delete, never retry); time/randomness/IO must be injectable; coverage threshold is a ratchet (up only).

## Workflow skills/agents

From **public Claude Code plugins** — preflight warns if a plugin isn't enabled. Nothing bundled.

- Bug investigation → `systematic-debugging` skill (`superpowers`).
- Post-feature review → `feature-dev:code-reviewer` agent or `/review-pr` (`pr-review-toolkit`).
- Plan multi-step tasks → `writing-plans` skill (`superpowers`).
- Execute plans with checkpoints → `executing-plans` skill (`superpowers`).

**Project-authored skills/agents** (if `.claude/skills/` or `.claude/agents/` exist): reference by name.

## Troubleshooting

`docs/troubleshooting.md` catalogs recurring blockers (Docker context on Windows, zombie containers, etc.). Check before filing "works on my machine".

## Architecture

Codebase map in `docs/architecture.md`. Session state in `.remember/now.md`. CLAUDE.md is a map of rules and commands, not a manual — use `grep` / `git log` for specifics.

## Maintenance

Goal: this file shrinks over time. Before adding, ask if Claude would already do it unprompted — if yes, don't. Audit quarterly; every line costs context every session × every dev.
