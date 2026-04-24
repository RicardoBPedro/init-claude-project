---
name: Testing standard (six principles)
description: Six principles + zero-tolerance rules; read before writing any test
type: reference
---

Before writing or modifying any test, apply these principles. They live in full in the project's `CLAUDE.md > Testing discipline` section and (optionally) in `docs/development/testing-standard.md` with stack-specific idioms.

**Six principles (ranked — top wins):**
1. Tests guarantee a business rule — coverage is a signal, not a goal.
2. Pick the lightest layer where the rule reads naturally. Unit > slice > integration.
3. Slow tests only for emergent behaviour — integration has a budget. Full-stack tests (Testcontainers, `@SpringBootTest`, Cypress, Playwright) are last resort, not default.
4. Skip rare + complex scenarios unless failure is catastrophic (financial / security / data integrity → test it anyway).
5. Test behaviour, not implementation. Mocks on boundaries only.
6. Every bug fix ships with a regression test that fails on the old code.

**Zero-tolerance:** flaky = broken (diagnose or delete, never retry); time/randomness/IO must be injectable; coverage threshold is a ratchet.
