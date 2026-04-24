---
name: Docs evolve with code
description: Every feature/fix must update relevant docs (CLAUDE.md, architecture, troubleshooting) in the same commit
type: feedback
---

Every change that affects a rule, command, file layout, or recurring issue must update the relevant doc IN THE SAME COMMIT — never as a follow-up.

**Why:** follow-up doc updates never happen. The commit author forgets, the reviewer doesn't notice (code got merged), and the doc silently drifts. Within 2–3 months the doc becomes misleading, and then everyone stops trusting it, and then it dies.

**How to apply:**
- New script in `scripts/` → reference it in CLAUDE.md.
- New recurring issue → add to `docs/troubleshooting.md`.
- New architecture decision → ADR in `docs/bmad/adrs/` or equivalent.
- Rule change → update CLAUDE.md in the same PR as the code enforcing it.
- Doc-less code change is suspicious: either truly trivial (fine) or you skipped the doc (not fine).
