---
name: Use Opus for heavy analysis
description: Always use Opus model for audits, security reviews, architecture reviews, and complex refactoring analysis
type: feedback
---

For audits, security reviews, architecture reviews, and any analysis requiring reasoning across many files, use the Opus model — not Sonnet or Haiku.

**Why:** shallow analysis on complex codebases produces generic findings that waste review cycles. The cost delta per audit is small relative to the cost of acting on a shallow finding or missing a real one. Speed isn't the bottleneck — judgment quality is.

**How to apply:**
- When dispatching a subagent for audit / review / security / architecture work, set `model: opus` explicitly.
- For simple lookups (file path, grep, single-file read), Sonnet is fine.
- If you're unsure whether the task is "heavy," assume yes — the cost of picking Opus wrongly is small; the cost of picking Sonnet wrongly is missing real issues.
