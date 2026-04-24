# CLAUDE.md — Mutation testing addendum (backend)

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

## PITest (how-to)

Default: don't run unless the diff is on a critical path AND non-trivial AND at a checkpoint (see the gate above).

**One-time config** in `build.gradle` (add under `plugins`):
```groovy
plugins {
  id 'info.solidsoft.pitest' version '1.15.0'
}

pitest {
  targetClasses      = ['com.example.auth.*', 'com.example.billing.*']  // scope to critical packages
  targetTests        = ['com.example.auth.*Test', 'com.example.billing.*Test']
  threads            = 4
  mutators           = ['STRONGER']
  outputFormats      = ['HTML', 'XML']
  timestampedReports = false
  avoidCallsTo       = ['org.slf4j', 'java.util.logging']
}
```

**Scoped run (reads `targetClasses` from config — normal mode):**
```bash
./gradlew pitest
```

**Override scope on the fly:**
```bash
./gradlew pitest -PtargetClasses=com.example.auth.TokenValidator
```

**Report:** `build/reports/pitest/index.html`. Look at mutation score per class — survived mutants = tests that touched the code but didn't assert the changed behavior. Fix the test, never lower the threshold.

**Budget sanity:** PITest + Testcontainers is brutal. Keep `targetTests` restricted to pure unit + slice tests; full-context `@SpringBootTest` classes blow the budget fast. Never run PITest in a commit / push / CI gate — it's a review-time tool.
