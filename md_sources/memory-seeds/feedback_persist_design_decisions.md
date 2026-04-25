---
name: Persist non-trivial design decisions
description: ADR-style note in docs/decisions/<date>-<slug>.md for trade-off choices, written before declaring the task done
type: feedback
---

For trade-off decisions — architecture pivots, library swaps, public-contract changes, anything where reasonable engineers would disagree — write a brief ADR to `docs/decisions/<YYYY-MM-DD>-<slug>.md` BEFORE declaring the task done.

**Why:** auto-memory captures preferences and project facts; specific trade-offs ("Y over X because Z") fall through — too contextual for project memory, too project-specific for user memory, not user-originated for feedback. Without a place to land they evaporate at session boundary and the next session re-derives or silently revisits.

**How to apply:**
- **Trigger:** "what trade-off did we accept", not "what's best". Skip trivial bugs, mechanical refactors, follow-the-pattern changes.
- **Format:** 5–15 lines. Context → Decision → Why (incl. alternatives) → Consequences.
- **Read first:** if existing ADRs cover the area, scan and cite; supersede explicitly when superseding.
