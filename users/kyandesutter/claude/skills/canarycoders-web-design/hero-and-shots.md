# Hero and app screenshots

## Hero markup

```astro
<section class="relative overflow-hidden">
  <div class="relative mx-auto max-w-[1120px] px-6 pt-16 lg:pt-24">
    <h1 class="rise max-w-3xl font-heading text-[40px] font-extrabold leading-[1.04] tracking-[-0.03em] text-ink sm:text-[60px] lg:text-[68px]">
      {t.hero.title1}
      <span class="relative inline-block whitespace-nowrap">
        {t.hero.title2}
        <!-- optional highlight under the key phrase, sweeps in after the title lands -->
        <span class="sweep absolute inset-x-0 bottom-1 -z-10 h-3 rounded-sm bg-accent-tint" aria-hidden="true"></span>
      </span>
    </h1>
    <p class="rise mt-6 max-w-xl text-[18px] leading-relaxed text-pretty text-muted" style="--rise-delay: 70ms">{t.hero.lede}</p>
    <div class="rise mt-8 flex flex-wrap items-center gap-x-6 gap-y-4" style="--rise-delay: 140ms">
      <a href={signup} class:list={[btn, "px-7 py-3 text-[15px]"]}>{t.hero.ctaPrimary}</a>
      <a href="#pricing" class={link}>{t.hero.ctaSecondary}</a>
    </div>
    <div class="rise mt-5 flex flex-wrap items-center gap-x-4 gap-y-3 text-[13px] text-faint" style="--rise-delay: 210ms">
      <span>{t.hero.ctaNote}</span>
    </div>
  </div>

  <!-- Wider than the text column; AppShot's sizes strings depend on these widths. -->
  <div class="mx-auto mt-14 max-w-[1240px] px-8 sm:px-6 lg:mt-18">
    <div class="shot-fade">
      <div class="shot-settle mx-auto max-w-[352px] rounded-[34px] bg-cream p-1.5 shadow-[inset_0_0_0_1px_var(--color-line),var(--shadow-shot)] sm:max-w-none sm:rounded-2xl sm:bg-transparent sm:p-0 sm:shadow-shot">
        <div class="overflow-hidden rounded-[28px] bg-paper shadow-[0_0_0_1px_var(--color-line)] sm:rounded-2xl sm:shadow-none">
          <AppShot locale={locale} alt={t.hero.shotAlt} />
        </div>
      </div>
    </div>
  </div>
</section>
```

Sweep keyframes (inside the reduced-motion block):

```css
@keyframes sweep { from { scale: 0 1; } }
.sweep { transform-origin: 0 50%; animation: sweep 0.45s var(--ease-out) 0.55s backwards; }
```

Rules:

* `.shot-fade` is the only gradient on the page: `mask-image: linear-gradient(to bottom, #000 55%, transparent 98%)`. The next section starts straight under it, no band.
* `.shot-settle` (tokens.md) runs only at `min-width: 64rem`, only with `@supports (animation-timeline: view())`, only without reduced motion. It animates `transform`, nothing else.
* The shot never gets `.rise`, `.reveal`, `opacity: 0` or `loading="lazy"`. It is the LCP element.
* Phones: the phone layout has no sidebar edge, so it gets the cream rim (outer `rounded-[34px] p-1.5`, inner `rounded-[28px]`, concentric). From `sm` up the shot carries its own edges and only gets `shadow-shot`.

## Capture pipeline

Screenshots come from the real app running locally against a seeded database.
Never capture production and never paint or mock a UI.

1. **Seed script** (`scripts/app-shots/seed-shots.ts`): creates a separate
   database (`<app>_shots`) with one demo account and healthy-looking data:
   realistic customer names, a mix of paid/sent/overdue with paid dominating,
   amounts that add up, dates in the last few months relative to today, no
   "Test", "Lorem" or zero balances.
2. **Run the stack** against that database: API on a spare port, the web app
   with a vite config that points at it.
3. **Capture script** (`scripts/app-shots/shots-run.ts`, Playwright): logs in as
   the demo user and writes one PNG per device x locale x scheme.

```ts
import { chromium } from "@playwright/test";

const DEVICES = {
  desktop: { suffix: "", viewport: { width: 1440, height: 876 }, deviceScaleFactor: 2 },
  tablet: { suffix: "-tablet", viewport: { width: 1366, height: 1024 }, deviceScaleFactor: 2, hasTouch: true },
  phone: { suffix: "-phone", viewport: { width: 390, height: 641 }, deviceScaleFactor: 3, isMobile: true, hasTouch: true },
} as const;

const browser = await chromium.launch();
for (const { suffix, ...device } of Object.values(DEVICES)) {
  for (const lang of ["es", "en"] as const) {
    for (const scheme of ["light", "dark"] as const) {
      const ctx = await browser.newContext({ ...device, colorScheme: scheme, locale: lang === "es" ? "es-ES" : "en-GB" });
      // Seed the app's own locale/theme storage keys here with ctx.addInitScript if it has them.
      const page = await ctx.newPage();
      await page.goto(`${BASE}/auth`);
      // fill the demo credentials, submit, wait for the app route
      if (suffix === "-phone") await page.goto(`${BASE}/`); // the screen that reads well on a phone
      await page.waitForLoadState("networkidle");
      await page.waitForTimeout(1200); // let charts and fonts settle
      await page.screenshot({ path: `${OUT}/home-${lang}-${scheme}${suffix}.png` });
      await ctx.close();
    }
  }
}
await browser.close();
```

Choosing the phone screen: open the app at 390 wide and pick the screen whose
native mobile layout is legible at 340px rendered width (a dashboard with big
numbers, not a wide list or table). Phone height ~641 keeps the shot from
dominating the hero.

Source PNGs live in `src/assets/` (so Astro's image pipeline can process them),
committed, regenerated only by the script.

## AppShot component

```astro
---
import { getImage } from "astro:assets";
// import every <screen>-<locale>-<scheme>[-phone|-tablet].png
interface Props { locale: "es" | "en"; alt: string }
const { locale, alt } = Astro.props;
const shots = { /* [locale][scheme][device] -> ImageMetadata */ }[locale];

// Widths cover 1x to 3x at each device's display size and never exceed the capture.
// sizes mirror the hero frame: 340px phone frame, full container on tablet, 1192px cap on desktop.
const devices = [
  { key: "phone", media: "(max-width: 639px)", sizes: "min(340px, calc(100vw - 64px))", widths: [360, 720, 1020] },
  { key: "tablet", media: "(max-width: 1023px)", sizes: "calc(100vw - 48px)", widths: [720, 1080, 1440, 1960] },
  { key: "desktop", media: "", sizes: "(min-width: 1240px) 1192px, calc(100vw - 48px)", widths: [1024, 1440, 1920, 2384] },
] as const;

const srcset = async (src: ImageMetadata, widths: readonly number[], format: "avif" | "webp") => {
  const out = await Promise.all(widths.map((width) => getImage({ src, width, format, quality: format === "avif" ? 60 : 78 })));
  return out.map((img, i) => `${img.src} ${widths[i]}w`).join(", ");
};
const join = (...parts: string[]) => parts.filter(Boolean).join(" and ");

const sources = [];
for (const device of devices) {
  for (const scheme of ["dark", "light"] as const) {   // dark first: its media query is more specific
    const src = shots[scheme][device.key];
    for (const format of ["avif", "webp"] as const) {  // avif first
      sources.push({
        media: join(device.media, scheme === "dark" ? "(prefers-color-scheme: dark)" : "") || undefined,
        type: `image/${format}`,
        srcset: await srcset(src, device.widths, format),
        sizes: device.sizes,
        width: src.width,
        height: src.height,
      });
    }
  }
}
const fallback = await getImage({ src: shots.light.desktop, width: 1440, format: "webp", quality: 78 });
---
<picture>
  {sources.map((s) => <source media={s.media} type={s.type} srcset={s.srcset} sizes={s.sizes} width={s.width} height={s.height} />)}
  <img src={fallback.src} width={shots.light.desktop.width} height={shots.light.desktop.height} alt={alt} decoding="async" class="block h-auto w-full" />
</picture>
```

Rules:

* Source order matters: the first matching `<source>` wins. Device (narrowest first), then dark before light, then AVIF before WebP.
* Width and height on every `<source>` (each device has a different aspect ratio) and on the `<img>`, so there is no layout shift.
* `sizes` must describe the rendered width at that breakpoint. If you change the hero container or padding, update `sizes`, then re-verify (verify.md).
* `alt` describes what the screen shows ("Invoice list with three paid and one overdue invoice"), not "screenshot".
* Docs screenshots use the same capture script at desktop size; in Starlight cap their rendered height (`max-height: 700px; width: auto`) and give them the card ring.
