---
name: Persist non-trivial design decisions
description: ADR-style note in docs/decisions/<date>-<slug>.md for trade-off choices, written before declaring the task done
type: feedback
---

For non-trivial design choices — architecture pivots, library swaps, public-contract changes, anything where reasonable engineers would disagree on trade-offs — write a brief ADR to `docs/decisions/<YYYY-MM-DD>-<slug>.md` BEFORE declaring the task done.

**Why:** auto-memory captures user preferences and project facts well, but specific design *trade-offs* ("we chose Y over X because Z") fall through — too contextual for project memory, too project-specific for user memory, didn't originate from feedback. Without a place to land, they evaporate at session boundary and the next session has to re-derive the *why* (or worse, silently revisit the decision differently).

**How to apply:**
- **Trigger:** decisions where the question is "what trade-off did we accept", not "what's best". Skip for trivial bugs, mechanical refactors, and changes that just follow an existing pattern.
- **Format:** 5–15 lines. *Context* (1 paragraph) → *Decision* (1 sentence) → *Why* (2–4 bullets, including alternatives considered) → *Consequences* (what this enables / forecloses).
- **File path:** `docs/decisions/<YYYY-MM-DD>-<short-slug>.md`. Date stamp prevents collisions and makes timeline obvious at a glance.
- **Read before writing:** if the task touches an area with existing ADRs, scan them first. Cite them in commit messages or supersede explicitly with a new ADR if the decision changes.
