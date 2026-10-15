---
name: safari-edge-colors
description: Make the areas behind iOS Safari's status bar and bottom toolbar match a page's top and bottom edges, so a hero runs edge to edge instead of sitting between grey browser bars. Covers fixed edge strips Safari extends behind its chrome, html/body background split, theme-color, viewport-fit=cover, and keeping it all in sync when the background changes on scroll. Use when building or reviewing a landing page or marketing site for mobile, when a hero "looks cut off on iPhone", when Safari's bars show the wrong colour, or when someone says theme-color isn't working. For general mobile web feel (tap highlight, 100vh, input zoom) use mobile-native.
---

# Matching Mobile Safari's Chrome to the Page

Source: Josh Puckett, <https://joshpuckett.me/seamless-mobile-safari> (October 2026).

## The problem

In the iOS Safari browser (not an installed web app), the status bar area and the
bottom control bar are painted with Safari's own chrome colour. A full-bleed hero
ends up framed by two bars that don't match it.

`<meta name="theme-color">` alone does not fix it:

* It works for installed apps, not reliably for pages in the browser.
* It is one colour, so the top and bottom can't differ.

## The technique

Safari extends the background of a **fixed element touching a viewport edge**
behind its controls. Put a thin fixed strip on the top edge and one on the
bottom edge, paint each with the colour of the content next to it, and Safari
uses those colours behind the status bar and the toolbar.

Four things carry the colour and must always agree:

1. the visible page background next to each edge,
2. `.edge-top::after` / `.edge-bottom::after`,
3. `html` (top colour) and `body` (bottom colour), which show during overscroll,
4. `<meta name="theme-color">` (top colour), for browsers that honour it.

### Markup

```html
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover" />
<meta name="theme-color" content="#004bff" />

<!-- direct children of body, outside any transformed / filtered / contained ancestor -->
<div class="edge-top" aria-hidden="true"></div>
<div class="edge-bottom" aria-hidden="true"></div>
```

### CSS

```css
:root {
  --edge-top-background: #004bff;
  --edge-bottom-background: #004bff;
}

html { background: var(--edge-top-background); }
body { background: var(--edge-bottom-background); }

.edge-top::after,
.edge-bottom::after {
  content: "";
  position: fixed;
  left: 0;
  right: 0;
  pointer-events: none;
}
.edge-top::after {
  top: 0;
  height: max(12px, env(safe-area-inset-top));
  background: var(--edge-top-background);
}
.edge-bottom::after {
  bottom: 0;
  height: max(12px, env(safe-area-inset-bottom));
  background: var(--edge-bottom-background);
}
```

Rules that make or break it:

* **Outside transformed ancestors.** `transform`, `filter`, `perspective`,
  `contain`, `will-change: transform` on an ancestor turn `position: fixed` into
  "fixed to that ancestor" and Safari no longer sees an edge element. Render the
  strips at the root (React: in the root layout, or a portal to `document.body`).
* **Solid colour per edge.** Each strip is one flat colour that matches the
  pixels next to it. Pick the colour at the very top / bottom of the hero, not
  the brand colour.
* **Keep the strips clear of content.** They are ~12px to the safe-area inset
  tall and sit above content in paint order; don't put text or controls under
  them. Give them a z-index below sticky headers if a header must cover them, or
  match the header colour instead.
* **`viewport-fit=cover`**, and keep text and controls inside the safe areas
  (`padding: env(safe-area-inset-*)` on the header, footer, fixed CTAs).
* **Dark mode.** If the page has light and dark themes, the edge variables and
  the theme-color meta tag follow the theme too (`media="(prefers-color-scheme: dark)"`
  on a second meta tag, or update both from the same variables).

## Dynamic colours (background changes on scroll)

Compute the palette once per frame and write it to every carrier together:

```ts
const meta = document.querySelector('meta[name="theme-color"]');
const root = document.documentElement;

function apply() {
  const { top, bottom } = paletteAt(window.scrollY); // your mapping
  root.style.setProperty("--edge-top-background", top);
  root.style.setProperty("--edge-bottom-background", bottom);
  meta?.setAttribute("content", top);
}

let raf = 0;
const schedule = () => { cancelAnimationFrame(raf); raf = requestAnimationFrame(apply); };

apply(); // covers a restored scroll position on load / bfcache
addEventListener("scroll", schedule, { passive: true });
addEventListener("resize", schedule);
visualViewport?.addEventListener("resize", schedule); // toolbar expanding / collapsing
addEventListener("pageshow", apply);

// on route leave (SPA): remove listeners, cancel the frame, and restore the
// previous --edge-* values and theme-color so the next page isn't tinted
```

The visible page background must read from the same values (or the same
`paletteAt`), otherwise the strips drift from what's under them.

## Limitations

* Solid colours only. Colours may change over time, but each edge is one colour.
* Images do not extend behind Safari's controls. A photo hero gets the colour of
  its top / bottom row of pixels, approximated.
* A gradient that changes left to right can't be matched.

## Workflow when applying it to a site

1. Find the root layout (the file that owns `<html>`, `<head>`, `<body>`).
2. Check the viewport meta for `viewport-fit=cover`; add it and audit fixed
   headers, footers and CTAs for safe-area padding before shipping.
3. Identify the top edge colour (first section / header) and bottom edge colour
   (footer) per theme. Read them from the existing tokens; never invent new ones.
4. Add the two strips at the root, the html/body backgrounds, and theme-color.
5. If the hero or header changes colour on scroll, wire the dynamic version.
6. Verify in the iOS Simulator Safari or a real iPhone: top and bottom at rest,
   scrolled, toolbar collapsed, overscroll at both ends, light and dark. Desktop
   devtools device mode does not show this behaviour.
