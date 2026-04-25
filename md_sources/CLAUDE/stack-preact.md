# CLAUDE.md — Preact addendum

<!--
  Merged into CLAUDE.md when type=frontend and FRONTEND_FLAVOR=preact.
  Assumed stack: TypeScript + Preact 10+ + Vite + @preact/preset-vite + Vitest + @testing-library/preact.
  Optional: @preact/signals, preact/compat (for React libraries), Playwright.
-->

Supplements core CLAUDE.md with Preact-specific best practices.

## Commands

```bash
npm run dev           # Vite dev server
npm run build         # production build
npm run test          # Vitest single run
npm run test:coverage # coverage report
npm run lint          # ESLint
npm run typecheck     # tsc --noEmit
npm run format        # Prettier
npm run test:e2e      # Playwright
```

Single file: `npx vitest run <path>`.

## Idiomatic patterns (DO)

- **`@preact/signals` for shared / cross-component state** — `signal(0)` exposes `.value`. Fine-grained, no provider.
- **`useSignal` for component-local signal state** — like `useState` with signal ergonomics: `const count = useSignal(0); count.value++`.
- **`computed()` for derived signals** — `const doubled = computed(() => count.value * 2)`. Lazy, cached, dependency-tracked.
- **`preact/compat` aliased in Vite** — alias `react` and `react-dom` to `preact/compat` in `vite.config.ts`.
- **Raw `preact` for your own UI**, `preact/compat` only at the boundary for third-party React libraries — keeps bundle small.
- **Read signals in JSX directly** — `<span>{count}</span>` updates the text node only, no component re-render.
- **Server-side rendering via `preact-render-to-string`** — minimal SSR, no streaming complexity.

## Anti-patterns (AVOID — call out and fix when seen)

- **Importing `react` directly without compat alias** — bundle bloat or runtime errors. Configure the alias in `vite.config.ts`.
- **Treating Preact as drop-in for every React feature** — concurrent features (`useTransition`, Suspense for data fetching, server components) are missing or partial.
- **`React.FC<Props>`** — same problems as React. Use `function Component(props: Props)`.
- **`useEffect` for derived state** — same trap as React. Compute inline or with `useMemo`/`computed`.
- **Mutating signal `.value` objects** — `count.value.items.push(x)` doesn't notify. Replace: `count.value = { ...count.value, items: [...] }`.
- **Forgetting `.value` outside JSX** — `if (count > 0)` reads the signal object, always truthy. Use `count.value > 0`.

## Test layer hierarchy

Pick the **lightest layer** where the rule reads naturally:

1. **Unit** — pure functions, signals/computed in isolation, components via `@testing-library/preact` + Vitest. Default.
2. **Component integration** — Testing Library + MSW. Fast, no browser.
3. **E2E** — Playwright. **LAST RESORT.** Only for cross-service flows.

## Tactical testing rules

- Use `@testing-library/preact` (not `@testing-library/react`) — Preact has its own renderer.
- For libraries assuming React, configure compat alias in the test runner's Vite config too.

## Stack-specific gotchas

- **`vite.config.ts` alias** — with compat, set `resolve.alias`: `{ react: 'preact/compat', 'react-dom': 'preact/compat' }`. Tests need it too.
- **Event names differ from React in some cases** — Preact accepts lowercase (`onclick`) AND camelCase (`onClick`); camelCase is canonical for portability.
- **`class` vs `className`** — Preact accepts both; standardize on `class` for new code, `className` if maintaining a React-ported codebase.
- **Bundle size regressions** — one React-only dep via `preact/compat` can blow up the bundle. Check `npm run build` size after each new lib.
- **Signals outside components** — `signal()` at module level is a singleton; treat like a global store.
- **Hydration mismatches** — `preact-render-to-string` output must match client render exactly; guard browser-only branches with `useEffect`.

## Accessibility / UI verification (for frontend stacks)

- `aria-label` on every interactive element without a visible label.
- Keyboard navigation: Tab, Enter, Space, Escape — all work.
- WCAG AA contrast: 4.5:1 body text, 3:1 large text, 3:1 UI components.
- Visible focus ring on every focusable element.
- `<label for="...">` bound to every form input.
