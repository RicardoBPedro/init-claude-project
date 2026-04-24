---
name: Global vs project-local skills/agents
description: domain-generic Claude artifacts → ~/.claude/; project-specific refs → <repo>/.claude/
type: feedback
---

Claude artifacts (skills, agents, commands, docs) live in two locations:

- **Global** (`~/.claude/...`) — reusable across ANY project. E.g. testing standards, generic audit agents, domain experts for APIs used across multiple projects (WhatsApp, OpenAI, Stripe).
- **Project-local** (`<repo>/.claude/...`) — only meaningful in this project. E.g. a skill that references specific module names, an agent that encodes this project's ADRs.

**Why:** cross-project reuse. Anything generic duplicated per-project rots out of sync and wastes refinement work. Anything project-specific leaked to `~/.claude/` pollutes every other project's context.

**How to apply:** when creating a new skill/agent/command, ask *"does this reference anything project-specific?"* If no → `~/.claude/`. If yes → `<repo>/.claude/` and link to it from project CLAUDE.md. If partially generic, refactor: move the generic parts to `~/.claude/`, keep a thin project-specific wrapper local.
