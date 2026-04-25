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

- **`function Component(props: Props)`** — explicit signature, no implicit `children`. Add `children: ReactNode` only if rendered.
- **`useId` for accessibility ids** — stable across SSR/CSR.
- **Server Components stay pure (Next.js)** — no hooks, handlers, browser APIs. Mark client islands with `'use client'`.
- **Exact `useEffect` dependency arrays** — let `react-hooks/exhaustive-deps` enforce. If it feels wrong, the effect shouldn't exist.

## Anti-patterns (AVOID — call out and fix when seen)

- **`React.FC<Props>`** — implicitly adds `children`, encourages deprecated `defaultProps`. Use `function Component(props: Props)`.
- **`useEffect` for derived state** — `useEffect(() => setFullName(first + ' ' + last))` is a re-render bug. Compute inline: `const fullName = first + ' ' + last`.
- **Mutating state directly** — `state.items.push(x)` won't re-render. Return a new reference.
- **Prophylactic `useMemo` / `useCallback`** — memoize only when a profiler shows it matters or downstream `memo` requires referential equality.
- **Index as key in mutable lists** — input state leaks across rows on reorder.
- **`dangerouslySetInnerHTML` with unsanitized input** — XSS. Sanitize with DOMPurify or render text.
- **Mixing controlled and uncontrolled inputs** — pick one. `value` without `onChange` triggers warnings.

## Test layer hierarchy

Pick the **lightest layer** where the rule reads naturally:

1. **Unit** — pure functions, hooks via `renderHook`, isolated components with RTL. Default.
2. **Component integration** — RTL + MSW. Fast, no browser.
3. **E2E** — Cypress / Playwright. **LAST RESORT.** Only for flows crossing real backend boundaries that can't be faithfully mocked (auth redirects, SSE, file downloads).

## Tactical testing rules

- Prefer `getByRole` / `data-testid` over `getByText` (i18n-friendly).

## Stack-specific gotchas

- **StrictMode double-invokes effects in dev** — effects must be idempotent or have cleanup.
- **Stale closures in effects/handlers** — capture via deps or `useRef` for "latest value" reads.
- **Hydration mismatches (Next.js)** — never branch on `typeof window` during render; use `useEffect` for client-only UI.
- **`useState` initializer** — pass a function for expensive defaults: `useState(() => heavyCompute())`.
- **Context re-renders** — every consumer re-renders on any value change. Split contexts by update frequency.

## Accessibility / UI verification (for frontend stacks)

- `aria-label` on every interactive element without a visible label.
- Keyboard navigation: Tab, Enter, Space, Escape — all work.
- WCAG AA contrast: 4.5:1 body text, 3:1 large text, 3:1 UI components.
- Visible focus ring on every focusable element.
- `<label>` bound to every form input.
