---
name: Authorized to edit Claude config on request
description: Proceed directly on ~/.claude/** and .claude/** edits when the user asks — don't re-prompt
type: feedback
---

When the user explicitly asks to modify Claude Code configuration — `~/.claude/**` (global) or `<repo>/.claude/**` (project) — proceed directly without re-prompting for permission. This includes:
- Editing `settings.json` (permissions, hooks, plugins)
- Creating/editing agents, skills, commands
- Editing CLAUDE.md
- Writing to `~/.claude/docs/`

**Why:** these are author-level edits to the user's own tooling. Re-prompting *"may I edit ~/.claude/settings.json?"* after the user already said *"add X to my settings"* wastes a turn.

**How to apply:** when the user's intent clearly maps to a Claude config edit, skip the confirmation step and make the edit. Still confirm for risky operations (deleting agents, removing permissions, disabling core plugins) or when the edit has unclear scope.
