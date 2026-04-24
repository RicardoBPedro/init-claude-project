# CLAUDE.md — Frontend addendum

<!--
  Merged into CLAUDE.md by the installer when type=frontend.
  Assumed stack: TypeScript + React + Vite + Vitest. Optional: Cypress, Playwright.
-->

This section supplements the core CLAUDE.md rules with frontend-specific commands and testing idioms.

## Commands

```bash
npm run dev           # Vite dev server
npm run test          # Vitest single run
npm run test:coverage # coverage report
npm run lint          # ESLint
npm run typecheck     # tsc --noEmit
npm run cypress:run   # headless E2E (if Cypress configured)
npm run test:a11y     # Playwright + axe a11y (if configured)
npm run test:visual   # Playwright visual regression (if configured)
```

Single file: `npx vitest run <path>`.

## Test layer hierarchy

Pick the **lightest layer** that reads naturally for the rule under test:

1. **Unit test** — pure functions, React Testing Library for isolated components. Default choice.
2. **Component integration** — RTL + MSW for API, testing component trees. Fast, no browser.
3. **E2E** — Cypress / Playwright. **LAST RESORT.** Only for flows that cross real backend boundaries and can't be faithfully mocked (auth redirects, server-sent events, file downloads).

Every time you reach for Cypress, pause and ask: *"Could component + MSW cover this?"* If yes, use that. E2E runs are slow, flaky-prone, and expensive to debug.

## Tactical testing rules

- Update tests + mocks + selectors before calling done.
- Auth mocks must include `ok: true` and `accessToken`.
- Prefer `getByRole` / `data-testid` over `getByText` to avoid ambiguity.
- Tests that set a session in `localStorage` must also set the refresh token and include `role` in the session JSON.
- Never lower coverage thresholds or skip tests. When a test fails, diagnose the root cause — don't disable the test or loosen the threshold.
- **Run only tests impacted by your change.** `npx vitest run <path>` during development. Full-suite runs need user approval.

## Accessibility baseline

- `aria-label` on every interactive element without visible label.
- Keyboard navigation: Tab, Enter, Space, Escape — all must work.
- WCAG AA contrast: 4.5:1 body text, 3:1 large text, 3:1 UI components.
- Visible focus ring on every focusable element.
- `<label>` bound to every form input.

## UI verification (DoD extension)

Before declaring frontend work done:
- Light + dark themes verified (if dark mode supported).
- Mobile (390px) + desktop layouts verified.
- Screenshots of both themes × both viewports for any visible change.

<!-- (Frontend-specific PostToolUse hooks are NOT installed by this template.
     Add them to .claude/settings.json yourself if you want prettier + eslint
     + tsc auto-runs after Write/Edit — the settings.json installed here
     only wires SessionStart + pre-push validation.) -->
