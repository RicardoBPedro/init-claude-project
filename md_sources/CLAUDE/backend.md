# CLAUDE.md — Backend addendum

<!--
  Merged into CLAUDE.md when type=backend.
  Assumed stack: Java + Spring Boot + Gradle + JUnit 5 + Testcontainers.
  If backend is Node/Python/Go, replace this file before install.
-->

Supplements core CLAUDE.md with backend-specific commands and testing idioms.

## Commands

```bash
./gradlew bootRun                                               # default profile
./gradlew bootRun --args='--spring.profiles.active=dev'         # dev profile
docker compose up -d                                            # local services (if compose present)
bash scripts/test-backend.sh                                    # full suite (wrapper — handles docker context + wrapper selection)
bash scripts/test-backend.sh --tests "FQCN"                     # single class
./gradlew compileJava compileTestJava                           # sanity check (no Testcontainers)
```

Windows hosts: `gradlew.bat` directly, or `scripts/test-backend.sh` (auto-picks the wrapper).

## Test layer hierarchy (HARD RULE)

Pick the **lightest layer** where the rule reads naturally. In order of preference:

1. **Unit** — pure POJOs, no Spring, no DB. Fastest, cheapest to maintain. Default.
2. **Slice** — `@WebMvcTest`, `@DataJpaTest`, `@JsonTest`, `@JdbcTest`. Loads only the relevant Spring layer. Fast (~1s), no Docker.
3. **Full context** — `@SpringBootTest` + Testcontainers. **LAST RESORT.** Only when the rule genuinely requires the full container (security filter chain, `AFTER_COMMIT` listeners, cross-service flows, Flyway migration validation against real Postgres).

Before every `@SpringBootTest` + Testcontainers, ask: *"Could a slice test (`@WebMvcTest` + `@MockBean`) cover this?"* If yes, use the slice. Testcontainers adds ~15–30s per test class and compounds fast.

**Full-suite `./gradlew test` is double-digit minutes.** Always run scoped: `bash scripts/test-backend.sh --tests "<FQCN>"`. Full-suite runs (release, closing an epic) need user approval.

## Tactical testing rules

- Scheduler tests inject `Clock.fixed(...)` — never rely on wall clock.
- Security assertions (401 / 403 / CORS) consolidate in a **single filter-chain contract test** — don't scatter across feature tests.
- Never lower coverage thresholds or skip tests. Diagnose the root cause when a test fails; don't disable it or loosen the threshold.
- Bug-fix regression tests must fail against the old code (principle 6) — verify by reverting locally and re-running.

## Migration discipline (Flyway / Liquibase)

Entity changes require a matching migration in the same PR. `ddl-auto=update` on H2 masks missing migrations in dev — validate against a clean DB before PR approval.

**Smoke test:** drop the dev DB, run the app from scratch, confirm boot + one smoke path. Missing column → missing migration.

## Known issues

`docs/troubleshooting.md` has the full catalog. Highlights:
- Windows + Testcontainers hang → `DOCKER_CONTEXT=desktop-linux`.
- Killed gradle run → zombie Ryuk + Postgres containers stall the next `:test`.
- Scheduler tests flake → wall clock leaked in; inject `Clock`.

<!-- (Backend PostToolUse hooks are NOT installed by this template. Add them
     to .claude/settings.json yourself if you want auto test runs after
     git commit — the settings.json here wires only SessionStart + pre-push
     validation.) -->
