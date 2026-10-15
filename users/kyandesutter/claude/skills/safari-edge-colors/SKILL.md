---
name: safari-edge-colors
description: Make the area behind iOS Safari's status bar match the top of the page, so a hero runs to the top edge instead of sitting under a grey browser bar. Covers the fixed top edge strip Safari extends behind its status bar, theme-color, viewport-fit=cover, and keeping it in sync when the top colour changes on scroll. Never a bottom strip (it shows as a band above the iOS 26+ floating tab bar). Use when building or reviewing a landing page or marketing site for mobile, when a hero "looks cut off on iPhone", when Safari's status bar shows the wrong colour, or when someone says theme-color isn't working. For general mobile web feel (tap highlight, 100vh, input zoom) use mobile-native.
---

# Matching Mobile Safari's Chrome to the Page

Source: Josh Puckett, <https://joshpuckett.me/seamless-mobile-safari> (October 2026).

## Status: failed in production, do not apply by default

Shipped to seven sites on 2026-10-15 and reverted the same day. On real devices
the fixed strips were visible: the bottom one as a band above the iOS 26+
floating tab bar, the top one (its 12px minimum) as a band on desktop and
wherever content scrolled under it. The iOS Simulator showed none of it. Only
apply this when the user asks for it by name, on a page whose top edge is one
flat colour at every scroll position, and verify on a real iPhone and on desktop
before shipping.

## The problem

In the iOS Safari browser (not an installed web app), the status bar area and the
bottom control bar are painted with Safari's own chrome colour. A full-bleed hero
ends up framed by two bars that don't match it.

`<meta name="theme-color">` alone does not fix it:

* It works for installed apps, not reliably for pages in the browser.
* It is one colour, so the top and bottom can't differ.

## The technique

Safari extends the background of a **fixed element touching a viewport edge**
behind its controls. Put a thin fixed strip on the top edge, paint it with the
colour of the content under it, and Safari uses that colour behind the status bar.

**Top strip only. Never add a bottom strip.** The source article also adds
one on the bottom edge, but on iOS 26+ Safari's tab bar floats over the page, and
on a real iPhone a fixed bottom strip shows as a solid band directly above the
tab bar that moves with it as the bar expands and collapses. Shipped that way to
seven sites on 2026-10-15 and had to pull it from all of them. The simulator
did not show the band.

Three things carry the colour and must always agree:

1. the visible page background under the top edge,
2. `.edge-top::after`,
3. `<meta name="theme-color">`, for browsers that honour it.

`html` may take the top colour for top overscroll. Never tie `body`'s background
to a changing edge colour: every transparent section on the page repaints with it.

### Markup

```html
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover" />
<meta name="theme-color" content="#004bff" />

<!-- direct child of body, outside any transformed / filtered / contained ancestor -->
<div class="edge-top" aria-hidden="true"></div>
```

### CSS

```css
:root {
  --edge-top-background: #004bff;
}

html { background: var(--edge-top-background); }

.edge-top::after {
  content: "";
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  height: max(12px, env(safe-area-inset-top));
  background: var(--edge-top-background);
  pointer-events: none;
}
```

Rules that make or break it:

* **Outside transformed ancestors.** `transform`, `filter`, `perspective`,
  `contain`, `will-change: transform` on an ancestor turn `position: fixed` into
  "fixed to that ancestor" and Safari no longer sees an edge element. Render the
  strips at the root (React: in the root layout, or a portal to `document.body`).
* **Solid colour.** The strip is one flat colour that matches the pixels under
  it. Pick the colour at the very top of the hero, not the brand colour.
* **Keep the strip clear of content.** They are ~12px to the safe-area inset
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
  const top = paletteAt(window.scrollY); // your mapping
  root.style.setProperty("--edge-top-background", top);
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
// previous --edge-top-background and theme-color so the next page isn't tinted
```

The visible page background must read from the same values (or the same
`paletteAt`), otherwise the strip drifts from what's under it.

## Limitations

* Solid colours only. The colour may change over time, but it is one colour.
* Images do not extend behind Safari's controls. A photo hero gets the colour of
  its top row of pixels as a phone crops it, approximated.
* The bottom toolbar is left to Safari (see above).
* A gradient that changes left to right can't be matched.

## Workflow when applying it to a site

1. Find the root layout (the file that owns `<html>`, `<head>`, `<body>`).
2. Check the viewport meta for `viewport-fit=cover`; add it and audit fixed
   headers, footers and CTAs for safe-area padding before shipping.
3. Identify the top edge colour (first section / header) per theme. Read them from the existing tokens; never invent new ones.
4. Add the top strip at the root, the html background, and theme-color.
5. If the hero or header changes colour on scroll, wire the dynamic version.
6. Verify on a real iPhone: top at rest, scrolled, toolbar collapsed, overscroll,
   light and dark. The simulator is a first pass only, and desktop devtools
   device mode does not show this behaviour at all.
