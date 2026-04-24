---
name: Coverage threshold is a ratchet
description: Never lower coverage thresholds; only raise. New code covered by tests that fail before the change.
type: feedback
---

Coverage threshold is a **ratchet — up only**. Never lower it to make a failing build pass.

**Why:** coverage trends downward naturally as features ship. The only counter-force is a hard gate that refuses regressions. Lowering the threshold once sets the precedent that it's negotiable — the next time it's easier, and the time after that easier still, until coverage is meaningless.

**How to apply:**
- If coverage dropped, the fix is MORE tests, not a lower threshold.
- If existing tests are flaky or slow, fix them or delete them — don't mask by lowering the bar.
- New features ship with tests that would FAIL against the pre-feature code (proves the test exercises the new path).
- Bug fixes ship with a regression test that FAILS against the pre-fix code.
- Never disable tests to unblock a merge. Diagnose the root cause of the failure and fix it.
