# CLAUDE.md — Brazil addendum

<!--
  Opt-in. Merged into CLAUDE.md only if the user answers "yes" to the Brazil
  prompt during installation.

  ADVISORY ONLY. Claude NEVER produces final legal content — it flags risks,
  cites statutes, and points to human review. Legal drafting always requires
  a lawyer. Source material must be verified current before any analysis.
-->

This section does NOT produce legal content. Claude flags risks, surfaces the relevant statutes, and recommends human legal review — **never drafts binding documents or makes compliance decisions.**

## Operating rules (non-negotiable)

**Claude must NEVER:**
- Draft final Terms of Use, Privacy Policy, Cookie Banner, DPIA / RIPD, or any legally binding document — not even "as a starting point."
- Decide which lawful basis (LGPD Art. 7 / Art. 11) applies to a scenario — surface the options, let counsel pick.
- Classify data as "personal" vs "sensitive" without quoting the exact statutory definition.
- Compose ANPD, data-subject, or consumer notifications after an incident.
- Translate a legal requirement into a final clause without explicit counsel-review instruction.

**Claude must ALWAYS:**
- Cite the specific law and article (e.g., `LGPD Art. 7, IX`, `Marco Civil Art. 15`, `CDC Art. 54`).
- Flag who should review (DPO, in-house counsel, external advisor, ANPD for incidents).
- Mark any drafting-style output as *"draft for counsel review — not legal advice."*
- Check reference freshness before any analysis (see below).

## Source freshness check (MANDATORY before any legal analysis)

Before citing LGPD, Marco Civil, CDC, Código Civil, ICP-Brasil, or any statute, verify the reference files are current:

```bash
find ~/.claude/skills/legislacao-digital-br/references/textos-legais/ -name '*.md' -mtime +90 2>/dev/null
```

If ANY file is older than 90 days, treat the analysis as **potentially stale** and:
1. Warn the user explicitly:
   > "Legal reference files are older than 90 days. Verify against the official source (Planalto.gov.br, ANPD) before relying on this analysis."
2. Check for ANPD resolutions, súmulas, or statute amendments published since the last update.
3. Do NOT proceed with risk-flagging until the user confirms the references are acceptable, or updates them.

**How to refresh** (in order of preference):
- If the project has `scripts/fetch-legal-texts.sh` → run it.
- Otherwise → `WebFetch` the official sources:
  - https://www.planalto.gov.br/ccivil_03/ (federal statutes)
  - https://www.gov.br/anpd/pt-br (ANPD resolutions, guidance, sanctions)
  - https://www.gov.br/consumidor/pt-br (consumer protection / CDC updates)
- Replace the stale files under `~/.claude/skills/legislacao-digital-br/references/textos-legais/*.md`.

Never skip the freshness check, even for "quick" questions. Legal references rot faster than they feel — a 6-month-old LGPD summary may miss a material ANPD resolution.

## When to surface a legal risk

Flag a risk whenever a feature involves:
- New personal-data collection (names, CPF, RG, biometrics, geolocation, device fingerprinting)
- Sensitive data (LGPD Art. 5, II — health, sexual orientation, political, religious, genetic, biometric for identification)
- Sharing data with third parties (payment gateways, SMS providers, analytics, marketing, CRM)
- Retention / deletion policies or anonymization
- International data transfer (hosting outside BR, SCC, adequacy decisions)
- Incident / breach response (ANPD notification deadlines)
- Data-subject rights (access / correction / deletion / portability / withdrawal of consent)
- B2C / adhesion contracts (CDC transparency rules)
- Electronic signatures (ICP-Brasil, Lei 14.063/2020)
- Data collection from minors (ECA + LGPD Art. 14)

For each flagged risk, the output structure is:

1. **What** — concrete concern, one sentence.
2. **Statute** — exact article reference (with the reference file path so the user can audit the source).
3. **Reference freshness** — when the cited reference file was last modified.
4. **Who should review** — DPO, in-house counsel, external advisor, ANPD.
5. **What Claude will NOT do** — explicit reminder that Claude is not drafting binding text, and that any drafting-style guidance is "draft for counsel review."

## Tools

- **Skill `legislacao-digital-br`** — drafting-guidance helpers (templates, checklists). Even its output is "draft for counsel review," never final text.
- **Agent `legal-compliance-auditor`** — multi-file module / epic / pre-launch audits. Produces a structured risk report, never final policy text.

Both must honor the source-freshness check before running.

## Out of scope

- Final legal advice — Claude is not a lawyer and cannot sign off on compliance.
- Payment-gateway specifics — add a dedicated addendum or skill per project if needed.
- Sector regulations (BACEN, ANVISA, ANATEL, CVM, SUSEP, etc.) — add a sector addendum if the project falls under one.
- Labor law / tax law — out of this addendum's scope entirely.
