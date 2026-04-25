# CLAUDE.md — Astro addendum

<!--
  Merged into CLAUDE.md when type=frontend and FRONTEND_FLAVOR=astro.
  Assumed stack: TypeScript + Astro 4+ + content collections + MDX. Optional UI integrations:
  @astrojs/react, @astrojs/svelte, @astrojs/vue, @astrojs/solid-js. Vitest or Playwright for tests.
-->

Supplements core CLAUDE.md with Astro-specific best practices.

## Commands

```bash
npm run dev           # Astro dev server
npm run build         # production build (static or hybrid)
npm run preview       # serve built output
npm run test          # Vitest single run
npm run lint          # ESLint
npm run typecheck     # astro check (wraps tsc + .astro diagnostics)
npm run format        # Prettier with prettier-plugin-astro
npm run test:e2e      # Playwright
```

Single file: `npx vitest run <path>`. Astro check on one file: `npx astro check`.

## Idiomatic patterns (DO)

- **Islands architecture** — hydrate only interactive bits with `client:*`; rest stays static HTML.
- **Pick the right `client:*` directive** — `client:load` (immediate), `client:idle`, `client:visible`, `client:media`, `client:only="react"` (skip SSR).
- **Content collections + Zod schemas** — `defineCollection({ schema: z.object({...}) })` in `src/content/config.ts`. Type-safe, validated at build.
- **`getCollection('blog')` / `getEntry`** — typed access to content. Replaces `import.meta.glob`.
- **MDX for content with components** — Markdown for prose, MDX when posts need interactive widgets.
- **Astro for layout, framework components for interactivity** — page shell in `.astro`, hydrate islands.
- **API endpoints as `.ts` files in `src/pages/api/`** — typed `APIRoute`, server-only, no client bundle.
- **View Transitions (`<ViewTransitions />`)** for SPA-like navigation without a SPA framework.

## Anti-patterns (AVOID — call out and fix when seen)

- **Hydrating everything with `client:load`** — defeats Astro's value. Default to no directive; opt in only when needed.
- **Heavy logic in `.astro` frontmatter that runs per-page** — push to `getStaticPaths` or build-time scripts.
- **Skipping content collection schemas** — untyped frontmatter rots silently. Define a Zod schema.
- **Fetching at runtime in static pages** — use `getStaticPaths` and build-time fetches; runtime requires SSR mode.
- **`client:only` without a fallback `slot="fallback"`** — users see nothing during JS load. Provide a placeholder.
- **Cross-island shared state via globals** — islands are isolated. Use nanostores, URL params, or co-locate state.
- **Putting secrets in `import.meta.env.PUBLIC_*`** — `PUBLIC_` ships to client. Server-only env vars omit the prefix.
- **Bypassing collections by reading files directly** — loses typing and HMR. Use `getCollection`.

## Test layer hierarchy

Pick the **lightest layer** where the rule reads naturally:

1. **Unit** — pure functions, content schema validators, island components via their framework's tools (RTL for React, @testing-library/svelte for Svelte). Default.
2. **Container Test API** — `experimental_AstroContainer.create()` to render `.astro` components in Vitest without a browser.
3. **E2E** — Playwright. **LAST RESORT.** Only for full-page rendering, view transitions, SSR-specific flows.

## Tactical testing rules

- Test island components with their native framework testing library — Astro doesn't intercept.
- Validate content schemas explicitly: `BlogSchema.parse(frontmatter)` catches drift before build.
- API route tests: import the route, call exported `GET`/`POST` with a mock `Request`.

## Stack-specific gotchas

- **Output mode matters** — `output: 'static'` builds HTML upfront; `'server'`/`'hybrid'` enable SSR endpoints. Adapter required for SSR.
- **`Astro.request` is undefined in static pages** — only available in SSR/hybrid. Use `getStaticPaths` for build-time variants.
- **`client:only` skips SSR** — for browser-only libs (charts, maps); pair with a static fallback to avoid CLS.
- **`set:html` is unsanitized** — XSS. Sanitize untrusted markup.
- **Image optimization via `<Image>` from `astro:assets`** — local assets sized/optimized; remote needs explicit width/height.
- **Integrations affect build, not just runtime** — `@astrojs/react` triggers JSX handling; remove when no React islands remain.

## Accessibility / UI verification (for frontend stacks)

- `aria-label` on every interactive element without a visible label.
- Keyboard navigation: Tab, Enter, Space, Escape — all work.
- WCAG AA contrast: 4.5:1 body text, 3:1 large text, 3:1 UI components.
- Visible focus ring on every focusable element.
- `<label for="...">` bound to every form input.
- View Transitions: ensure focus is restored sensibly across navigations.
