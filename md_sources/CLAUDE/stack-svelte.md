# CLAUDE.md — Svelte / SvelteKit addendum

<!--
  Merged into CLAUDE.md when type=frontend and FRONTEND_FLAVOR=svelte.
  Assumed stack: TypeScript + Svelte 5 (runes) / SvelteKit + Vite + Vitest + @testing-library/svelte.
  Optional: Playwright (SvelteKit's default E2E).
-->

Supplements core CLAUDE.md with Svelte-specific best practices.

## Commands

```bash
npm run dev               # Vite / SvelteKit dev server
npm run build             # production build (SvelteKit: adapter output)
npm run test              # Vitest single run
npm run test:coverage     # coverage report
npm run lint              # ESLint (eslint-plugin-svelte)
npm run check             # svelte-check (typecheck + diagnostics)
npm run format            # Prettier
npm run test:e2e          # Playwright
```

Single file: `npx vitest run <path>`. SvelteKit single E2E: `npx playwright test <path>`.

## Idiomatic patterns (DO)

- **Svelte 5 runes** for new code — `$state`, `$derived`, `$effect`, `$props`. Drop legacy `let count = 0` reactivity.
- **`$derived` for computed, `$effect` for side-effects** — `$derived` recomputes lazily; `$effect` runs imperatively for DOM/network.
- **`$props()` with TypeScript types** — `let { name, count = 0 }: { name: string; count?: number } = $props()`. Replaces `export let`.
- **`.svelte.ts` modules for shared reactive logic** — runes work outside components. Test as plain modules.
- **`+page.server.ts` `load`** for server-only data and secrets — body never ships to client.
- **`+page.ts` `load`** for universal data — keep free of secrets, fetch from public APIs.
- **Form actions with `use:enhance`** — progressive enhancement; works without JS, JS upgrades the UX.
- **`$bindable()` for two-way bindable props** — explicit opt-in beats Svelte 4's implicit `bind:` to `export let`.
- **`{#each items as item (item.id)}`** with keyed each — required for stable transitions and DOM reuse.
- **Snippets (`{#snippet}` / `{@render}`)** over slots in Svelte 5 — typed, reusable, composable.

## Anti-patterns (AVOID — call out and fix when seen)

- **Legacy `let` reactivity in new code** — `let count = 0` no longer reactive in runes mode. Use `let count = $state(0)`.
- **`$effect` for derived data** — re-running an effect to set another `$state` is a render-loop trap. Use `$derived`.
- **`$:` reactive statements in new code** — runes (`$derived`, `$effect`) replace them.
- **Server secrets in `+page.ts`** — file ships to client. Use `+page.server.ts` and `$env/static/private`.
- **Mutating props directly** — read-only unless `$bindable()`. Emit via callback prop or use `$bindable`.
- **Suppressing a11y compiler warnings** — `<!-- svelte-ignore a11y-... -->` is debt. Fix the markup.
- **Calling `goto()` inside `load`** — use `redirect(302, '/path')` from `@sveltejs/kit` so SSR works.
- **Deep nested `$effect`** — effects that read and write state cause loops. Keep flat and one-directional.

## Test layer hierarchy

Pick the **lightest layer** where the rule reads naturally:

1. **Unit** — pure functions, runes-driven `.svelte.ts` modules, isolated components via `@testing-library/svelte` + Vitest. Default.
2. **Component integration** — Testing Library + MSW for fetch/load functions; `+page.server.ts` exports tested directly.
3. **E2E** — Playwright. **LAST RESORT.** Only for cross-service flows mocks can't cover.

## Tactical testing rules

- Test runes by importing the `.svelte.ts` module — skip DOM unless asserting DOM.
- `+page.server.ts` `load` / `actions`: test as plain functions with mock `event.locals`. No SvelteKit runtime.

## Stack-specific gotchas

- **`$state` is deeply reactive by default** — for large arrays/objects use `$state.raw()` to skip proxying.
- **`$effect` runs after the DOM updates** — for pre-update hooks use `$effect.pre()`.
- **`load` runs on server and client by default** — branch with `browser` from `$app/environment`.
- **Form actions return type-narrowed `ActionData`** — let TypeScript drive the response shape; don't `as any`.
- **`use:enhance` swallows errors silently if no handler** — always provide the callback.
- **Adapters change deployment shape** — `adapter-node`, `adapter-vercel`, `adapter-static` differ in what `load` can do.

## Accessibility / UI verification (for frontend stacks)

- `aria-label` on every interactive element without a visible label.
- Keyboard navigation: Tab, Enter, Space, Escape — all work.
- WCAG AA contrast: 4.5:1 body text, 3:1 large text, 3:1 UI components.
- Visible focus ring on every focusable element.
- `<label for="...">` bound to every form input.
- Don't suppress Svelte's a11y compiler warnings — fix them.
