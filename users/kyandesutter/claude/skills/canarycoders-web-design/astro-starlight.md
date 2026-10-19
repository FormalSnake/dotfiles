# Astro 7, Starlight, legal and 404 pages

## Astro 7

| Gotcha | Fix |
| --- | --- |
| Spaces before inline links, `<strong>` or `<em>` vanish across a line break | Astro 7 defaults to JSX whitespace rules. Set `compressHTML: true` in `astro.config.mjs` to keep HTML rules for hand-written prose. Check a paragraph with a link after the change. |
| A nested 404 (`/en/404`) builds to `en/404/index.html` and is served as a 200 | Add a `astro:build:done` hook that moves it to `en/404.html` (Workers static assets only treat a literal `<dir>/404.html` as not-found). |
| Sitemap lists noindex pages | Filter 404s and noindexed legal pages out of `@astrojs/sitemap`. |
| Localised slugs break the sitemap's `i18n` option | Keep one `ROUTE_PAIRS` table (key, es path, en path) and derive hreflang, the language switcher and sitemap alternates from it. |

Tailwind v4 goes in through `@tailwindcss/vite` in `vite.plugins`, tokens in
`global.css` (tokens.md). Icons per icons.md.

## Starlight docs

Theme with one `src/styles/brand.css` in `customCss`. Starlight's default
scheme is dark on `:root`, light on `:root[data-theme="light"]`.

| Gotcha | Fix |
| --- | --- |
| Map the brand onto Starlight's ramp | `--sl-color-accent-low/accent/accent-high`, `--sl-color-black` (page bg), `--sl-color-white` (strongest text), `--sl-color-gray-1..7`, `--sl-color-hairline*`, `--sl-color-bg-nav`, `--sl-color-bg-sidebar` (both = page bg). Same OKLCH values as the marketing site. |
| Page title | Is `h1#_top`. Style it with the display face, `clamp(2rem, 1.5rem + 2vw, 2.625rem)`, weight 800, `-0.03em`. |
| Safe-area padding on the header misaligns the row | Target `header.header` only. The inner flex row is also `.header`, and padding both pushes it off centre. |
| Mobile menu button sits under the notch | Position `.sl-menu-button` with `top: calc(env(safe-area-inset-top) + (var(--nav-base) - var(--sl-menu-button-size)) / 2)` and grow `--sl-nav-height` by the inset. |
| Cards rotate through Starlight's rainbow icon colours | Override `.card`: `--sl-card-border: transparent`, `--sl-card-bg: <second-tint>`, `border: 0`, `border-radius: 1rem`, paper background, `box-shadow: <shadow-card>`; `.card .icon { color: <second-text> }`. |
| Asides use blue and purple | Override `.starlight-aside--note, --tip` to the brand secondary: `--sl-color-asides-text-accent`, `--sl-color-asides-border`, tinted background. Drop the edge bar: `border: 0; border-radius: 0.875rem; box-shadow: inset 0 0 0 1px color-mix(in oklch, var(--sl-color-asides-border) 30%, transparent)`. |
| Links are solid accent | Underline at 35% `currentColor`, full on hover, `text-underline-offset: 0.2em`. Exclude `.not-content`, `.card a`, `.sl-link-card a`. |
| Sidebar current page is an inverted bar | `[aria-current="page"]` gets the accent tint background and the strongest text colour, `border-radius: 0.5rem`. |
| Bar tint on iOS | `:root { background-color: var(--sl-color-bg-nav) }` and `viewport-fit=cover` via the `head` config option. |

Also: tables as a ruled paper panel (hairline rows, tinted `th`, rounded,
`overflow: hidden`), link cards and pagination with `shadow-card` and an
accent ring on hover (no lift), hero actions as pills with `scale: 0.96` on
`:active`, the same `--ease-out` curve, `tabular-nums` in tables and code.
Splash hero left-aligned like the marketing site.

## Legal pages

One `Legal.astro` layout wrapping every legal page:

* Big title: `font-heading text-[36px] sm:text-[52px] font-extrabold leading-[1.06] tracking-[-0.03em] text-balance`, `.rise`.
* Under it, `border-t border-line pt-10`, a two-column grid `lg:grid-cols-[200px_1fr]`.
* Left: a nav of all legal pages, `lg:sticky lg:top-28 lg:self-start`; current page `aria-current="page"`, semibold ink on the accent tint pill; wraps into a row on mobile.
* Right: `.legal-prose max-w-[680px]`: h2 `1.375rem` bold display face with `margin-top: 3rem`; body `1rem / 1.7` muted, `text-wrap: pretty`; faint list markers; underlined accent links; blockquotes as cream panels; tables as the same ruled panel as pricing (`border-radius: 1rem`, `box-shadow: 0 0 0 1px line`, cream `th`).
* `noindex, follow` by default, out of the sitemap, still linked from the footer.

## 404

Same shell as the site: big `.rise` title, a one-sentence body, a pill button
home, then a short row of real links (pricing, FAQ, docs, contact, log in) in
the visitor's locale. No illustrations, no jokes about lost astronauts.
