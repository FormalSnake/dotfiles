# Tokens and global CSS

A complete `src/styles/global.css` skeleton for Astro + Tailwind v4. Values are
the CanaryFactura palette (orange accent, teal secondary, cream/ink neutrals).
For another brand keep the structure and the lightness ladder, swap the hues
and the accent chroma to the brand's colours.

## Fonts

Self-host the variable `.woff2` files (copy from `@fontsource-variable/*`), only
the latin subset plus anything the page actually renders. Declare `@font-face`
by hand with `font-display: swap` and `unicode-range`, then preload the two
critical files in `<head>` with `crossorigin` (font fetches are CORS mode;
without it the browser fetches twice).

```css
@import "tailwindcss";

@font-face {
  font-family: "Montserrat Variable";
  font-style: normal;
  font-display: swap;
  font-weight: 100 900;
  src: url("/fonts/montserrat-latin-wght-normal.woff2") format("woff2-variations");
  unicode-range: U+0000-00FF, U+0131, U+0152-0153, U+02BB-02BC, U+02C6, U+02DA, U+02DC,
    U+0304, U+0308, U+0329, U+2000-206F, U+20AC, U+2122, U+2191, U+2193, U+2212, U+2215,
    U+FEFF, U+FFFD;
}
/* Same block for the body face. */
```

## Colour tokens

Raw values on `:root`, flipped for dark, mapped to utilities with `@theme inline`.

```css
:root {
  color-scheme: light;
  --canvas: oklch(0.985 0.004 80);   /* page */
  --cream: oklch(0.968 0.008 70);    /* alternate bands, panels */
  --paper: oklch(0.997 0.002 80);    /* cards */
  --ink: oklch(0.235 0.018 250);     /* text */
  --muted: oklch(0.48 0.02 65);      /* body copy */
  --faint: oklch(0.54 0.016 65);     /* notes, labels: lightest L that keeps 4.5:1 on cream */
  --line: oklch(0.9 0.009 72);       /* hairlines */
  --accent: oklch(0.67 0.165 40);
  --accent-deep: oklch(0.58 0.155 38); /* hover on accent buttons */
  --accent-text: oklch(0.52 0.14 38);  /* accent as text, passes contrast */
  --accent-tint: oklch(0.955 0.028 45);
  --second-text: oklch(0.44 0.075 215);
  --second-tint: oklch(0.945 0.03 210);
  --ok: oklch(0.48 0.1 150);
  --warn-tint: oklch(0.955 0.045 90);
  --warn-text: oklch(0.5 0.1 75);
  --band: oklch(0.235 0.018 250);    /* inverted callout band */
  --band-fg: oklch(0.97 0.006 75);
  /* Warm-tinted, so cards read as paper on cream rather than grey on cream. */
  --shadow-card: 0 0 0 1px oklch(0.3 0.03 60 / 0.08), 0 1px 2px oklch(0.3 0.03 60 / 0.06),
    0 8px 24px -12px oklch(0.3 0.03 60 / 0.16);
  --shadow-shot: 0 0 0 1px oklch(0.3 0.03 60 / 0.1), 0 2px 4px oklch(0.3 0.03 60 / 0.05),
    0 24px 60px -24px oklch(0.3 0.03 60 / 0.28);
}

@media (prefers-color-scheme: dark) {
  :root {
    color-scheme: dark;
    --canvas: oklch(0.205 0.012 255);
    --cream: oklch(0.235 0.012 255);
    --paper: oklch(0.26 0.013 255);
    --ink: oklch(0.93 0.006 75);
    --muted: oklch(0.7 0.012 70);
    --faint: oklch(0.64 0.012 70);   /* 4.5:1 on paper, the lightest dark surface */
    --line: oklch(0.31 0.012 255);
    --accent: oklch(0.69 0.16 40);
    --accent-deep: oklch(0.62 0.15 38);
    --accent-text: oklch(0.78 0.12 42);
    --accent-tint: oklch(0.34 0.06 45);
    --second-text: oklch(0.78 0.08 210);
    --second-tint: oklch(0.3 0.035 215);
    --ok: oklch(0.75 0.11 150);
    --warn-tint: oklch(0.31 0.04 85);
    --warn-text: oklch(0.82 0.1 90);
    --band: oklch(0.165 0.012 255);  /* darker than canvas on dark */
    --band-fg: oklch(0.93 0.006 75);
    /* On dark the ring carries the edge; the drop shadow only adds depth. */
    --shadow-card: 0 0 0 1px oklch(1 0 0 / 0.07), 0 8px 24px -12px oklch(0 0 0 / 0.5);
    --shadow-shot: 0 0 0 1px oklch(1 0 0 / 0.09), 0 24px 60px -24px oklch(0 0 0 / 0.7);
  }
}

@theme inline {
  --color-canvas: var(--canvas);
  --color-cream: var(--cream);
  --color-paper: var(--paper);
  --color-ink: var(--ink);
  --color-muted: var(--muted);
  --color-faint: var(--faint);
  --color-line: var(--line);
  --color-accent: var(--accent);
  /* ...one line per token above... */
  --shadow-card: var(--shadow-card);
  --shadow-shot: var(--shadow-shot);
  --font-sans: "Open Sans Variable", system-ui, sans-serif;
  --font-heading: "Montserrat Variable", var(--font-sans);
}

/* Replaces Tailwind's ease-out, so `ease-out` utilities and the CSS below share one curve. */
@theme {
  --ease-out: cubic-bezier(0.23, 1, 0.32, 1);
}
```

Rules for the ladder: dark neutrals sit on a cool hue (~255) at chroma 0.012,
light neutrals on a warm hue (65 to 80) at chroma 0.002 to 0.02. Accent text and
accent fill are separate tokens because the fill colour rarely passes 4.5:1 as
text. Check every text/surface pair with a contrast tool before shipping.

## Motion

```css
@media (prefers-reduced-motion: no-preference) {
  html { scroll-behavior: smooth; }

  @keyframes rise { from { opacity: 0; translate: 0 12px; } }
  .rise {
    animation: rise 0.5s var(--ease-out) backwards;
    animation-delay: var(--rise-delay, 0ms);
  }

  /* Gated on .js so content is never hidden without JavaScript. */
  .js .reveal {
    opacity: 0;
    translate: 0 12px;
    transition: opacity 0.5s var(--ease-out), translate 0.5s var(--ease-out);
    transition-delay: var(--reveal-delay, 0ms);
  }
  .js .reveal.in { opacity: 1; translate: 0 0; }

  /* Animated <details> (FAQ). Needs interpolate-size; others open instantly. */
  details::details-content {
    block-size: 0;
    overflow-y: clip;
    opacity: 0;
    translate: 0 -4px;
    transition: content-visibility 0.2s allow-discrete, opacity 0.15s var(--ease-out),
      translate 0.2s var(--ease-out), block-size 0.2s var(--ease-out);
  }
  details[open]::details-content {
    block-size: auto;
    opacity: 1;
    translate: 0 0;
    transition: content-visibility 0.3s allow-discrete, opacity 0.3s var(--ease-out) 0.05s,
      translate 0.3s var(--ease-out), block-size 0.3s var(--ease-out);
  }

  /* Hero shot settle, see hero-and-shots.md. */
  @supports (animation-timeline: view()) {
    @media (min-width: 64rem) {
      @keyframes settle {
        from { transform: perspective(1800px) rotateX(9deg) scale(0.97); }
      }
      .shot-settle {
        transform-origin: 50% 0;
        animation: settle linear both;
        animation-timeline: view();
        animation-range: entry 0% cover 45%;
      }
    }
  }
}

.shot-fade { mask-image: linear-gradient(to bottom, #000 55%, transparent 98%); }

@supports (interpolate-size: allow-keywords) {
  :root { interpolate-size: allow-keywords; }
}
```

In `<head>`, before any stylesheet-dependent paint:

```html
<script is:inline>document.documentElement.classList.add("js");</script>
```

At the end of `<body>`:

```html
<script>
  const els = document.querySelectorAll(".reveal");
  if (els.length && matchMedia("(prefers-reduced-motion: no-preference)").matches) {
    const io = new IntersectionObserver((entries) => {
      for (const e of entries) if (e.isIntersecting) { e.target.classList.add("in"); io.unobserve(e.target); }
    }, { rootMargin: "0px 0px -10% 0px" });
    for (const el of els) io.observe(el);
  }
</script>
```

Stagger reveals inside a group with `style="--reveal-delay: 60ms"` steps, never more than ~300ms total.

## Base and mobile

```css
/* Anchor targets clear the sticky header. */
[id] { scroll-margin-top: calc(5rem + env(safe-area-inset-top)); }

:focus-visible { outline: 2px solid var(--color-accent); outline-offset: 2px; }

/* In @layer base so Tailwind transition utilities on CTAs still win. */
@layer base {
  a, summary { transition: color 0.15s ease; }
}

/* iOS Safari tints its bars from the html background. */
html {
  background-color: var(--color-canvas);
  -webkit-tap-highlight-color: transparent;
  -webkit-text-size-adjust: 100%;
}
a, button, summary { touch-action: manipulation; }

body {
  background-color: var(--color-canvas);
  color: var(--color-ink);
  font-family: var(--font-sans);
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

::selection { background: var(--color-accent); color: var(--color-paper); }
```

`<meta name="theme-color">` per scheme with the canvas hex, for browsers other
than iOS 26 Safari (which ignores it).

## Header

Sticky, hairline bottom border, glass background on an `aria-hidden` child so
Safari samples the transparent sticky element and falls back to `html`:

```html
<header class="sticky top-0 z-40 border-b border-line pt-[env(safe-area-inset-top)]">
  <div aria-hidden="true" class="absolute inset-0 bg-canvas/90 backdrop-blur-md"></div>
  <div class="relative mx-auto flex h-15 max-w-[1120px] items-center gap-4 px-6 sm:gap-7">
    <!-- brand mark + name (name hidden under 380px), nav (sm+), language, login (sm+), CTA -->
  </div>
</header>
```

Language switcher (`Icon` is the build-time Nucleo wrapper from icons.md):

```astro
<a href={otherPath} rel="alternate" hreflang={otherLocale} lang={otherLocale}
  class="inline-flex items-center gap-1.5 py-2 text-[13.5px] font-medium text-muted hover:text-ink"
  ><Icon icon={IconGlobeFillDuo18} class="size-[15px]" /><span class="max-[399px]:sr-only">{otherLocaleName}</span></a>
```

Header CTA: `whitespace-nowrap rounded-full bg-accent px-4.5 py-2 text-[13px] font-bold text-paper transition-[scale,background-color] duration-150 ease-out hover:bg-accent-deep active:scale-[0.96]`.

Include a skip link (`sr-only focus:not-sr-only`, styled as the pill CTA when focused).
