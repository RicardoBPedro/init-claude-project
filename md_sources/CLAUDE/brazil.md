# CLAUDE.md — Brazil addendum

<!--
  Opt-in. ADVISORY ONLY. Claude NEVER produces final legal content.
  Sources MUST be refreshed via WebFetch before analysis — toolkit does
  NOT bundle legal references.
-->

This section does NOT produce legal content. Claude flags risks, surfaces the relevant statutes, and recommends human legal review — **never drafts binding documents or makes compliance decisions.**

## Operating rules (non-negotiable)

**Claude must NEVER:**
- Draft final Terms of Use, Privacy Policy, Cookie Banner, DPIA / RIPD, or any legally binding document — not even "as a starting point."
- Decide which lawful basis (LGPD Art. 7 / Art. 11) applies — surface the options, let counsel pick.
- Classify data as "personal" vs "sensitive" without quoting the exact statutory definition.
- Compose ANPD, data-subject, or consumer notifications after an incident.
- Cite legislation from training data as if it were current — training cutoffs rot fast for regulatory material.

**Claude must ALWAYS:**
- Cite the specific law and article (`LGPD Art. 7, IX`, `Marco Civil Art. 15`, `CDC Art. 54`).
- Flag who reviews (DPO, in-house counsel, external advisor, ANPD for incidents).
- Mark drafting-style output as *"draft for counsel review — not legal advice."*
- Refresh sources via `WebFetch` before any analysis (see below).

## Source freshness (MANDATORY before any legal analysis)

Toolkit does not bundle legal references. Before citing LGPD / Marco Civil / CDC / Código Civil / ICP-Brasil / any Brazilian statute, Claude MUST refresh from the official publisher.

**Required sequence:**
1. `WebFetch` the relevant statute from its authoritative source:
   - Federal statutes (LGPD, Marco Civil, CDC, Código Civil, Lei 14.063/2020) → `https://www.planalto.gov.br/ccivil_03/`
   - LGPD resolutions, guidance, sanctions → `https://www.gov.br/anpd/pt-br/assuntos/regulamentacao`
   - Consumer-protection updates → `https://www.gov.br/consumidor/pt-br`
2. Confirm the fetched version is the current consolidated text (Planalto: "Publicação original" + "Textos consolidados"; ANPD: check published-date).
3. Cite the retrieved article directly. If `WebFetch` fails or returns stale/unclear content, STOP and tell the user: *"Could not verify current statute text from the official source. Legal analysis halted. Please manually confirm and re-run."*

**Never cite from training data alone.** If `WebFetch` isn't available or the official source is unreachable, the answer is: *"I can't verify the current statute text — please consult counsel directly."*

**Optional acceleration:** if the project has a local legal-references skill (e.g. `~/.claude/skills/<legal-skill>/references/textos-legais/`), check freshness:

```bash
find ~/.claude/skills/ -path '*textos-legais*' -name '*.md' -mtime +90 2>/dev/null
```

Files <90 days old may be a starting point — but always cross-check the cited article via `WebFetch` before quoting. Older or missing files → `WebFetch` is the single source of truth.

## When to surface a legal risk

Flag a risk whenever a feature involves:
- New personal-data collection (names, CPF, RG, biometrics, geolocation, device fingerprinting)
- Sensitive data (LGPD Art. 5, II — health, sexual orientation, political, religious, genetic, biometric for identification)
- Sharing data with third parties (payment gateways, SMS, analytics, marketing, CRM)
- Retention / deletion / anonymization policies
- International data transfer (hosting outside BR, SCC, adequacy decisions)
- Incident / breach response (ANPD notification deadlines)
- Data-subject rights (access / correction / deletion / portability / consent withdrawal)
- B2C / adhesion contracts (CDC transparency)
- Electronic signatures (ICP-Brasil, Lei 14.063/2020)
- Data collection from minors (ECA + LGPD Art. 14)

For each flagged risk, output:

1. **What** — concrete concern, one sentence.
2. **Statute** — exact article reference (+ WebFetch URL used to verify).
3. **Source verification** — URL + date fetched.
4. **Who reviews** — DPO, in-house counsel, external advisor, ANPD.
5. **What Claude will NOT do** — reminder that Claude isn't drafting binding text; drafting-style guidance is "draft for counsel review."

## Tools (not bundled)

Toolkit installs no legal skill or agent. If your team has one, reference it by name here — otherwise Claude operates from the rules above + `WebFetch`.

Team-authored artifacts you might build:
- A skill packaging common statutory references + checklists (still outputs "draft for counsel review")
- An agent running a multi-file compliance audit on a module/epic (structured risk report, never final policy text)

## Out of scope

- Final legal advice — Claude is not a lawyer and cannot sign off on compliance.
- Payment-gateway specifics — add a per-project addendum or skill if needed.
- Sector regulations (BACEN, ANVISA, ANATEL, CVM, SUSEP) — add a sector addendum if applicable.
- Labor law / tax law — out of scope entirely.
