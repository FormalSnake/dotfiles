---
name: canarycoders-web-design
description: How CanaryCoders designs and builds websites (marketing sites, landing pages, docs sites, legal and 404 pages), usually Astro + Tailwind v4 or Starlight. Concrete house rules for OKLCH brand tokens and dark mode, warm shadows, one card/button language, copy (Microsoft style, banned words, no em dashes, Spanish tú), a distinct composition per section, a Linear-style hero with a real product screenshot, per-device screenshot capture and responsive <picture> delivery, motion, mobile and iOS Safari polish, Nucleo icons, Astro 7 and Starlight gotchas, and the screenshot verification pass before shipping. Use when building, redesigning or reviewing any CanaryCoders web page, or any site that should look like ours. Self-contained: copy the directory into ~/.claude/skills/ to install.
---

# CanaryCoders web design

The house style for our websites. Every rule below is a decision we already
made; don't reopen it per project. Reference implementation: the CanaryFactura
site (CanaryInvoice repo, `apps/website` and `apps/docs`).

If you have them installed, these skills go deeper on one axis each:
`frontend-design`, `better-colors`, `better-typography`, `better-layout`,
`better-ui`, `better-accessibility`, `better-writing`, `emil-design-eng`,
`animate`, `transitions-dev`, `mobile-native`, `safari-bar-tint`,
`baseline-ui`, `apple-design`. This skill wins where they disagree.

## Reference files (load on demand)

| File | Load when |
| --- | --- |
| [tokens.md](tokens.md) | Setting up `global.css`: tokens, dark mode, shadows, fonts, motion CSS, mobile base, header |
| [sections.md](sections.md) | Composing any page section; catalogue of 12 patterns with Tailwind snippets |
| [hero-and-shots.md](hero-and-shots.md) | Building the hero, capturing app screenshots, the `<picture>` component |
| [icons.md](icons.md) | Adding any icon; Nucleo packages, the Astro wrapper, licence key setup, install errors |
| [copy.md](copy.md) | Writing or reviewing any shipped string, EN or ES |
| [astro-starlight.md](astro-starlight.md) | Astro 7 config, Starlight docs theming, legal and 404 pages |
| [verify.md](verify.md) | Before every commit that changes how a page looks |

## Visual rules

| Area | Rule |
| --- | --- |
| Brand | Keep the brand's colours and fonts. Never swap the display face or accent for "something more modern". |
| Tokens | Raw OKLCH values on `:root`, flipped under `@media (prefers-color-scheme: dark)`, mapped with Tailwind `@theme inline`. No hex in components. |
| Neutrals | Tinted, never pure white or black. Light canvas around `oklch(0.985 0.004 80)`, ink around `oklch(0.235 0.018 250)`. Faint text stays at 4.5:1 or better. |
| Surfaces | Three: `canvas` (page), `cream` (alternate band, panels), `paper` (cards). |
| Shadows | Two warm-tinted tokens only: `--shadow-card`, `--shadow-shot`. On dark the 1px ring carries the edge. |
| One language | Cards `rounded-2xl bg-paper shadow-card`. Panels `rounded-3xl bg-cream` + inset 1px line ring. Buttons are pills (`rounded-full`, bold). Pills `rounded-full px-2.5 py-0.5 text-[12px] font-semibold` on a tint. Define these once as class constants per page. |
| Type | Display face for h1/h2/h3, tracking tightens with size (`-0.03em` at 60px+, `-0.02em` at h2). `text-balance` on headings, `text-pretty` on body. `tabular-nums` on money and numbers. |
| Layout | Content max `1120px`, `px-6` gutter, sections `py-20 lg:py-28`. Hero shot container `1240px`. |
| Icons | Nucleo only (`nucleo-ui-fill-duo-18`, `nucleo-ui-outline-18`, `nucleo-core-outline-24`, `nucleo-micro-bold`, `nucleo-flags`), named imports. In Astro without React, render them to inline SVG at build time. Never Lucide, never hand-written SVG. One icon colour per set. Needs `NUCLEO_LICENSE_KEY` at install: [icons.md](icons.md). |

Never:

* Eyebrows or kickers above headings.
* A subtitle that restates the heading. The body adds a fact or it goes.
* Uppercase tracked labels. Labels are sentence case `text-[13px] font-semibold text-faint`.
* Glows, coloured blurs, hover lifts (`translateY` on hover), hover shadows that grow.
* Gradients, except functional masks (the hero shot fade, scroll edge fades).
* Rotating rainbow icon colours across a grid. One brand colour.
* Mockups or illustrations of the product. Real screenshots only.
* The same composition twice in a row. Every section gets its own ([sections.md](sections.md)).

## Hero (Linear-style)

1. Big left-aligned h1 (`40px / 60px / 68px`, extrabold, `leading-[1.04]`), lede `18px` muted, primary pill CTA + underlined secondary link, one faint note row.
2. The product screenshot is inside the hero, wider than the text column (`max-w-[1240px]` vs `1120px`), fading into the page with a bottom mask.
3. Desktop only: scroll-driven settle tilt, `animation-timeline: view()`, transform only, inside `@supports` and `prefers-reduced-motion: no-preference`.
4. Never an opacity entrance on the screenshot. It is the LCP element; text gets the `rise` entrance, the image paints immediately.
5. Phones: shot in a cream rim/bezel (`rounded-[34px] p-1.5`). Wider: no rim, hairline ring (`shadow-shot`).

Full markup and the capture pipeline: [hero-and-shots.md](hero-and-shots.md).

## Screenshots

* Real app, seeded local demo account with healthy-looking data. Never production.
* Per device, light and dark: phone `390` wide @3x with mobile emulation (pick a screen that reads well on a phone, e.g. the dashboard, not a wide table), tablet `1366x1024` @2x, desktop `1440` @2x.
* Delivered with `<picture>`: per-device `media` sources x scheme x AVIF + WebP, `srcset` with `w` descriptors capped at the capture width, `sizes` that match the real rendered width, explicit `width`/`height`.
* Verify which candidate each viewport actually picks ([verify.md](verify.md)).

## Motion

* One curve: `--ease-out: cubic-bezier(0.23, 1, 0.32, 1)`, replacing Tailwind's `ease-out` so utilities and CSS share it.
* Page-load `rise` (opacity + 12px translate, 500ms) staggered 70ms per chunk via `--rise-delay`.
* Scroll `reveal` gated on a `.js` class set inline in `<head>`, so nothing hides without JS. IntersectionObserver adds `.in` once.
* Press: `active:scale-[0.96]`, 150ms, on every button and pill CTA.
* Hover styles only matter on hover-capable devices (Tailwind v4 `hover:` already compiles to `@media (hover: hover)`); never rely on hover for information.
* All of it inside `prefers-reduced-motion: no-preference`. Animate `transform`/`opacity`/`scale`/`translate` only.

## Mobile and iOS Safari

* `-webkit-tap-highlight-color: transparent`, `-webkit-text-size-adjust: 100%` on `html`; `touch-action: manipulation` on `a, button, summary`.
* `viewport-fit=cover`; sticky header pads `env(safe-area-inset-top)`, footer pads the bottom inset.
* CTAs `whitespace-nowrap`. Hit areas at least `py-2` on text links.
* Language switcher: Nucleo globe icon + the other language's endonym ("Español", "English") with `lang` and `hreflang`; label goes `sr-only` under 400px.
* Safari bar tint comes from the `html` background colour, set to the colour the sticky header sits on. Glass header: background and blur on an `aria-hidden` absolute child, not the sticky element. No edge strips, no pseudo-element bars.

## Copy

Microsoft Writing Style Guide: "you", contractions, active voice, sentence
case everywhere, short sentences, no marketing words. No em dashes and no
spaced en dashes in any shipped text. Spanish uses tú with the same
principles. Banned list and examples: [copy.md](copy.md).

## Scope

Redesign every page the site ships, not only home: legal pages (big title,
sticky legal nav, readable prose, ruled tables), 404, Stripe/partner pages,
docs. A redesigned home next to a default-styled legal page is unfinished.

## Ship checklist

1. Build passes, lint passes.
2. Screenshots light + dark at phone 390, tablet 1366, desktop 1440 with a clean headless browser, every page you touched. Look at them.
3. `<picture>` candidates verified per viewport; images have width/height; no opacity on the LCP image.
4. `rg -n '\x{2014}|\s\x{2013}\s' src` returns nothing (em dash, spaced en dash).
5. Reduced motion and no-JS both show all content.
