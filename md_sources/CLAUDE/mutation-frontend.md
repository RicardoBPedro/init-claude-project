# CLAUDE.md — Mutation testing addendum (frontend)

<!--
  Opt-in. Merged into CLAUDE.md only if the user answers "yes" to the mutation
  testing prompt during installation. Skip unless the project has genuine
  critical-path code (auth, money, state machines, data integrity) where
  weak-assertion smell detection justifies the tooling cost.
-->

## Mutation testing (on-demand only)

Mutation testing catches tests that execute code without asserting meaningfully — the "passes coverage but verifies nothing" smell that plain coverage can't detect. It's expensive (the test suite re-runs once per mutant) so it **does NOT belong in the default commit / push / CI loop**.

**Run mutation testing only when ALL three conditions hold:**
1. The code is on a **critical path** — authentication, authorization, money (payments, refunds, ledger, commissions), state machines, data-integrity invariants, security-sensitive decisions.
2. The change is **non-trivial** — meaningful behavior change, not rename / comment / formatting / import shuffle.
3. You're at a **checkpoint** — pre-release, pre-merge of a high-stakes feature, post-incident review, or an explicit audit request.

**Do NOT run mutation testing for:**
- UI components, layouts, CSS, copy changes
- Pure CRUD without business invariants
- Transient / experimental / prototype code
- Normal feature development (the 6 testing principles cover this)
- Any pre-commit / pre-push / SessionStart hook — too slow, wrong tempo

**How Claude should behave:** when a diff lands on a critical path AND the change is non-trivial, proactively offer: *"This module qualifies for mutation testing — want me to run it?"* — don't run autonomously. Outside the critical-path list, don't even mention mutation testing.

**Interpreting the report:** a surviving mutant is a test that executed the mutated line but didn't catch the change — i.e. a weak assertion or a missing test. Fix the test, never lower the threshold.

**Budget sanity:** if a scoped run takes >10 min, tighten the scope. Full-codebase mutation runs are pre-release only.

## Stryker (how-to)

Default: don't run unless the diff is on a critical path AND non-trivial AND at a checkpoint (see the gate above).

**One-time install + init (when first critical module qualifies):**
```bash
npm install --save-dev @stryker-mutator/core @stryker-mutator/vitest-runner @stryker-mutator/typescript-checker
npx stryker init
```

**Scoped run — narrow to one critical module (the normal mode):**
```bash
npx stryker run --mutate "src/auth/**/*.ts,src/auth/**/*.tsx"
```

**Unscoped — whole codebase (pre-release only, very expensive):**
```bash
npx stryker run
```

**Report:** `reports/mutation/mutation.html`. Survived mutants = weak assertions. Fix the test, not the threshold.

**Budget sanity:** if scoped run takes >10 min, tighten the `--mutate` glob further. Never block a commit or push on Stryker output — it's a review-time tool, not a gate.
