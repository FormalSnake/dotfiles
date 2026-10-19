# Verification

Run before every commit that changes how a page looks. "Done" means you
looked at the screenshots.

## 1. Build and lint

Use the project's own scripts (`bun run build`, `bun run lint`, `astro check`).
Fix the first error first.

## 2. Screenshots, every touched page

Serve the production build (`bun run build && bun run preview`), then capture
light and dark at three widths with a clean headless browser (no extensions,
no cache, no logged-in state):

```sh
URL=http://localhost:4321/
OUT=./.shots; mkdir -p $OUT
for scheme in light dark; do
  bunx playwright screenshot --viewport-size=390,844   --color-scheme=$scheme --full-page --wait-for-timeout=800 "$URL" $OUT/phone-$scheme.png
  bunx playwright screenshot --viewport-size=1366,1024 --color-scheme=$scheme --full-page --wait-for-timeout=800 "$URL" $OUT/tablet-$scheme.png
  bunx playwright screenshot --viewport-size=1440,900  --color-scheme=$scheme --full-page --wait-for-timeout=800 "$URL" $OUT/desktop-$scheme.png
done
```

Add `--device "iPhone 15"` for a phone pass with mobile emulation and touch.
Keep `.shots/` out of git.

Look for: horizontal scroll on phone, wrapped CTAs, a section that repeats the
previous composition, uppercase or eyebrow labels, pure white/black surfaces,
dark-mode contrast on faint text, the hero shot fade landing cleanly.

## 3. Which image each viewport picks

`<picture>` mistakes are invisible in screenshots (a desktop shot squeezed onto
a phone still "looks fine"). Check `currentSrc` and the rendered width:

```ts
// verify-shots.ts, run with: bun verify-shots.ts http://localhost:4321/
import { chromium } from "@playwright/test";
const url = process.argv[2];
const cases = [
  { name: "phone", viewport: { width: 390, height: 844 }, deviceScaleFactor: 3, isMobile: true, hasTouch: true },
  { name: "small-tablet", viewport: { width: 820, height: 1180 }, deviceScaleFactor: 2 },
  { name: "tablet", viewport: { width: 1366, height: 1024 }, deviceScaleFactor: 2 },
  { name: "desktop", viewport: { width: 1440, height: 900 }, deviceScaleFactor: 2 },
];
const browser = await chromium.launch();
for (const c of cases) for (const colorScheme of ["light", "dark"] as const) {
  const ctx = await browser.newContext({ ...c, colorScheme });
  const page = await ctx.newPage();
  await page.goto(url, { waitUntil: "networkidle" });
  const r = await page.locator("picture img").first().evaluate((img: HTMLImageElement) => ({
    src: img.currentSrc.split("/").pop(),
    rendered: Math.round(img.getBoundingClientRect().width),
    natural: img.naturalWidth,
  }));
  console.log(c.name, colorScheme, r, "needed ~", r.rendered * (c.deviceScaleFactor ?? 1));
  await ctx.close();
}
await browser.close();
```

Pass when every row shows the right device file (phone shot on phone), the
right scheme, AVIF where supported, and `natural` at or just above `needed`.
A `natural` far above `needed` means `sizes` is wrong; far below means the
widths list is missing a step.

## 4. Lighthouse-safe

* LCP image: no opacity entrance, no lazy loading, explicit width/height.
* Fonts: two preloads with `crossorigin`, `font-display: swap`, latin subset only.
* No layout shift from reveals (they translate, never change size).
* `prefers-reduced-motion: reduce` and JavaScript disabled both show every section.

## 5. Copy

```sh
rg -n '\x{2014}|\s\x{2013}\s' src
```

Must return nothing. Then read every changed string once against copy.md.
