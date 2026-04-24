# CLAUDE.md — Backend addendum

<!--
  Merged into CLAUDE.md by the installer when type=backend.
  Assumed stack: Java + Spring Boot + Gradle + JUnit 5 + Testcontainers.
  If your backend is Node/Python/Go, replace this file before install.
-->

This section supplements the core CLAUDE.md rules with backend-specific commands and testing idioms.

## Commands

```bash
./gradlew bootRun                                               # default profile
./gradlew bootRun --args='--spring.profiles.active=dev'         # Dev profile
docker compose up -d                                            # local services (if compose present)
bash scripts/test-backend.sh                                    # full suite (wrapper — handles docker context + wrapper selection)
bash scripts/test-backend.sh --tests "FQCN"                     # single class
./gradlew compileJava compileTestJava                           # sanity check without Testcontainers
```

Windows hosts: use `gradlew.bat` directly, or `scripts/test-backend.sh` (picks the right wrapper automatically).

## Test layer hierarchy (HARD RULE)

Pick the **lightest layer** that reads naturally for the rule under test. In order of preference:

1. **Unit test** — pure POJOs, no Spring, no DB. Fastest, cleanest, cheapest to maintain. Default choice.
2. **Slice test** — `@WebMvcTest`, `@DataJpaTest`, `@JsonTest`, `@JdbcTest`. Loads only the relevant Spring layer. Fast (~1s), no Docker.
3. **Full context test** — `@SpringBootTest` + Testcontainers. **LAST RESORT.** Only when the rule genuinely requires the full container (security filter chain, `AFTER_COMMIT` listeners, cross-service flows, Flyway migration validation against real Postgres).

Every time you reach for `@SpringBootTest` + Testcontainers, pause and ask: *"Could a slice test (`@WebMvcTest` + `@MockBean`) cover this?"* If yes, use the slice. A Testcontainers run adds ~15–30s of overhead per test class and compounds fast.

**Full-suite `./gradlew test` runs currently take double-digit minutes.** Always run scoped: `bash scripts/test-backend.sh --tests "<FQCN>"`. Full-suite runs before a release or before closing an epic need user approval.

## Tactical testing rules

- Scheduler tests must inject a `Clock.fixed(...)` — never rely on wall clock.
- Security assertions (401 / 403 / CORS) consolidate into a **single filter-chain contract test** — don't scatter across feature tests.
- Never lower coverage thresholds or skip tests. Use the `fix-tests` skill to resolve failures autonomously.
- When a bug is fixed, the regression test must fail against the old code (principle 6) — verify by reverting the fix locally and re-running.

## Mutation testing — PITest (on-demand, critical paths only)

See `CLAUDE.md > Mutation testing` for WHEN to run. This section covers HOW. Default: don't run unless the diff is on a critical path AND non-trivial AND at a checkpoint.

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

## Known issues

`docs/troubleshooting.md` has the full catalog. Highlights:
- Windows + Testcontainers hang → `DOCKER_CONTEXT=desktop-linux`.
- Killed gradle run → zombie Ryuk + Postgres containers stall the next `:test`.
- Scheduler tests fail intermittently → wall clock leaked in; inject `Clock`.

## Backend hooks

The `.claude/settings.json` installed by this template wires a `PostToolUse` hook after `git commit` that runs the scoped test suite for touched modules. Tune the matcher if your repo has a different layout.
