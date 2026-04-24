# CLAUDE.md — Brazil addendum

<!--
  Opt-in. Merged into CLAUDE.md only if the user answers "yes" to the Brazil
  prompt during installation. Keeps Brazilian legal context visible to Claude
  without bloating non-BR projects.
-->

This section supplements the core CLAUDE.md rules with Brazil-specific legal and compliance context.

## Legal context

Products serving Brazilian users are subject to:
- **LGPD** (Lei 13.709/2018) — data protection. Requires lawful basis, data subject rights (access / correction / deletion / portability), incident notification, DPO in some cases.
- **Marco Civil da Internet** (Lei 12.965/2014) — internet usage rules, connection + application log retention (6–12 months).
- **CDC** (Código de Defesa do Consumidor, Lei 8.078/1990) — B2C contracts, transparency in adhesion clauses, consumer rights.
- **Lei 14.063/2020** + ICP-Brasil (MP 2.200-2/2001) — electronic signatures.

Any feature that collects, processes, or shares personal data must have a clear lawful basis under LGPD Art. 7 or Art. 11 (sensitive data).

## When to invoke the `legislacao-digital-br` skill

Available globally if installed (`~/.claude/skills/legislacao-digital-br/`). Invoke when:
- Drafting or reviewing Terms of Use, Privacy Policy, Cookie Banner
- Adding a new data collection point (names, documents, location, biometrics, device fingerprinting)
- Sharing data with third parties (payment gateways, SMS providers, marketing platforms, analytics)
- Setting up retention / deletion policies
- Responding to a security incident or data breach (ANPD notification timelines)
- Implementing data subject rights (access / correction / deletion / portability endpoints)
- International data transfer (hosting outside Brazil, SCCs, adequacy decisions)

## When to invoke the `legal-compliance-auditor` agent

For broader reviews — a full epic, module, or pre-launch audit — use the `legal-compliance-auditor` agent instead of the skill. It does multi-file scans and produces a formal compliance report; the skill is for single-task drafting/validation.

## What this addendum does NOT include

- Specific legal templates (policy text, DPIA template, incident report) — those live in the global skill at `~/.claude/skills/legislacao-digital-br/templates/`.
- Payment gateway specifics — add a gateway-specific addendum or skill in your project if needed.
- Sector regulations (health / BACEN / ANVISA / ANATEL) — add a sector-specific addendum in your project if applicable.
