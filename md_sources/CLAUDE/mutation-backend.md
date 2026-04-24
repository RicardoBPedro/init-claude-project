# CLAUDE.md — Mutation testing addendum (backend)

<!--
  Opt-in. Skip unless the project has genuine critical-path code (auth, money,
  state machines, data integrity) where weak-assertion detection justifies the
  tooling cost.
-->

## Mutation testing (on-demand only)

Catches tests that execute code without asserting meaningfully — the "passes coverage but verifies nothing" smell that plain coverage can't detect. Expensive (test suite re-runs per mutant), so **NOT in the default commit / push / CI loop**.

**Run only when ALL three hold:**
1. **Critical path** — auth, authz, money (payments, refunds, ledger, commissions), state machines, data-integrity invariants, security-sensitive decisions.
2. **Non-trivial change** — meaningful behavior change, not rename / comment / formatting / import shuffle.
3. **Checkpoint** — pre-release, pre-merge of a high-stakes feature, post-incident review, or explicit audit request.

**Do NOT run for:** UI / layouts / CSS / copy; pure CRUD without invariants; transient / experimental / prototype code; normal feature development (6 testing principles cover it); any commit / push / SessionStart hook (too slow).

**Claude behavior:** when a diff lands on a critical path AND is non-trivial, proactively offer: *"This module qualifies for mutation testing — want me to run it?"* Never run autonomously. Outside the critical-path list, don't mention it.

**Interpreting:** a surviving mutant = test executed the mutated line without catching the change = weak assertion or missing test. Fix the test; never lower the threshold.

**Budget:** scoped run >10 min → tighten scope. Full-codebase runs only pre-release.

## PITest (how-to)

See the gate above for WHEN. Don't run unless the diff is on a critical path AND non-trivial AND at a checkpoint.

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

**Report:** `build/reports/pitest/index.html`. Mutation score per class — survived mutants = tests that touched the code but didn't assert the changed behavior. Fix the test, not the threshold.

**Budget:** PITest + Testcontainers is brutal. Keep `targetTests` restricted to unit + slice; `@SpringBootTest` classes blow the budget fast. Never run PITest in a commit / push / CI gate — review-time only.
