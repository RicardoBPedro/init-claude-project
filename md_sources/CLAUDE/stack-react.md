# CLAUDE.md — React addendum

<!--
  Merged into CLAUDE.md when type=frontend and FRONTEND_FLAVOR=react (the default).
  Assumed stack: TypeScript + React 18+ + Vite + Vitest + React Testing Library. Covers the React family:
  Next.js, Remix, plain Vite SPAs. Optional: Cypress, Playwright, MSW.
-->

Supplements core CLAUDE.md with React-specific best practices.

## Commands

```bash
npm run dev           # Vite dev server
npm run build         # production build
npm run test          # Vitest single run
npm run test:coverage # coverage report
npm run lint          # ESLint
npm run typecheck     # tsc --noEmit
npm run format        # Prettier
npm run cypress:run   # headless E2E
npm run test:a11y     # Playwright + axe
```

Single file: `npx vitest run <path>`.

## Idiomatic patterns (DO)

- **`useId` for accessibility ids** — stable across SSR/CSR; counters and `Math.random()` break hydration.
- **Server Components stay pure (Next.js App Router)** — no hooks, handlers, browser APIs. Mark client islands with `'use client'`.
- **`exhaustive-deps` is non-negotiable** — if the linter wants a dep you don't want to add, the effect shouldn't exist.

## Anti-patterns (AVOID — call out and fix when seen)

- **`React.FC<Props>`** — implicitly adds `children`, encourages deprecated `defaultProps`. Use `function Component(props: Props)`.
- **Prophylactic `useMemo` / `useCallback`** — memoize only when a profiler shows it matters or downstream `memo` requires referential equality.

## Test layer hierarchy

Pick the **lightest layer** where the rule reads naturally:

1. **Unit** — pure functions, hooks via `renderHook`, isolated components with RTL. Default.
2. **Component integration** — RTL + MSW. Fast, no browser.
3. **E2E** — Cypress / Playwright. **LAST RESORT.** Only for flows crossing real backend boundaries that can't be faithfully mocked (auth redirects, SSE, file downloads).

## Stack-specific gotchas

- **StrictMode double-invokes effects in dev** — effects must be idempotent or have cleanup.
- **Stale closures** in effects/handlers — capture via deps or `useRef` for "latest value" reads.
- **Hydration mismatches (Next.js)** — never branch on `typeof window` during render; use `useEffect` for client-only UI.
- **`useState` initializer for expensive defaults** — `useState(() => heavyCompute())`, not `useState(heavyCompute())`.
- **Context re-renders** — every consumer re-renders on any value change. Split contexts by update frequency.

## Accessibility (frontend stacks)

WCAG AA: keyboard nav (Tab/Enter/Space/Esc), labelled inputs, visible focus, contrast 4.5:1 body / 3:1 UI / 3:1 large text.
