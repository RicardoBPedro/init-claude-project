---
name: Never leave orphan branches
description: Run bash scripts/branch-hygiene.sh at session start+end; investigate stale branches before new work
type: feedback
---

Orphan / stale branches (local commits with no clear integration path) are forbidden. Run `bash scripts/branch-hygiene.sh` at session start and before handoff.

**Why:** lost work is the worst failure mode. A branch with 40 commits that no one remembers becomes dead weight in every audit and is easy to delete by accident. Making stale branches visible every session prevents slow accumulation.

**How to apply:**
- Session start: run the hygiene script. If it flags stale branches, investigate BEFORE starting new work.
- When pushing a new branch: know its integration path (PR review, pipeline, etc.). If unknown, don't push yet.
- Never silently delete a stale branch — inspect first (commits, diff vs main, merge-base age), then let the user decide: rebase, cherry-pick, push, or abandon. Lost work is worse than a messy branch list.
