# Section patterns

Every section on a page gets its own composition. Pick the pattern from what
the content is (a statement, a flow, a comparison, a list of equals), never
from what the previous section used. Two adjacent sections never share a
pattern, and backgrounds alternate `canvas` / `cream` with `border-y
border-line` on the cream band.

Shared constants at the top of the page component:

```ts
const h2 = "font-heading text-[30px] font-bold leading-[1.1] tracking-[-0.02em] text-balance sm:text-[38px]";
const card = "rounded-2xl bg-paper shadow-card";
const btn = "inline-flex items-center justify-center rounded-full bg-accent font-bold text-paper transition-[scale,background-color] duration-150 ease-out hover:bg-accent-deep active:scale-[0.96]";
const pill = "rounded-full px-2.5 py-0.5 text-[12px] font-semibold";
const link = "group inline-flex items-center gap-1.5 py-2 text-[15px] font-semibold text-ink underline decoration-line decoration-2 underline-offset-[6px] transition-[text-decoration-color] hover:decoration-current";
const label = "text-[13px] font-semibold text-faint"; // sentence case, never uppercase
```

Body copy under a heading: `text-[16px] leading-relaxed text-pretty text-muted`, `max-w-lg` to `max-w-2xl`.
`Icon` below is the build-time Nucleo wrapper from icons.md.

| # | Pattern | Fits |
| --- | --- | --- |
| 1 | Statement paragraph with faint continuation | The problem, right after the hero |
| 2 | Split header over a wide panel | A feature with one concrete visual (rates, a table) |
| 3 | Chain / flow diagram | Things that link in sequence (records, steps that depend) |
| 4 | Centered flow | A two-system integration, A to B |
| 5 | Two-column with tilted mock | What the end customer sees |
| 6 | Ruled grid with shared borders | Six to nine equal features |
| 7 | Inverted band callout | A deadline, one urgent fact |
| 8 | Ruled pricing table, tinted featured column | Pricing |
| 9 | Stage track roadmap | Now / soon / later |
| 10 | Sticky-heading FAQ with rotating plus | FAQ |
| 11 | Closing CTA band with brand mark | Last section before the footer |
| 12 | Hero with product shot | Top of the page (hero-and-shots.md) |

"Mock" in 3 and 5 means a small composed card built from real copy and real
numbers, used only for a concept the app has no single screen for. The product
itself is always a real screenshot.

## 1. Statement paragraph with faint continuation

Heading and body read as one paragraph; the second half is faint.

```astro
<section class="mx-auto max-w-[1120px] px-6 pb-8 pt-12 lg:pt-16">
  <h2 class="max-w-4xl font-heading text-[26px] font-bold leading-[1.25] tracking-[-0.015em] text-pretty sm:text-[34px]">
    {t.problem.title}{" "}<span class="text-faint">{t.problem.body}</span>
  </h2>
</section>
```

## 2. Split header over a wide panel

```astro
<section class="mx-auto max-w-[1120px] px-6 py-20 lg:py-28">
  <div class="grid gap-x-16 gap-y-5 lg:grid-cols-2 lg:items-end">
    <h2 class:list={[h2, "max-w-xl"]}>{title}</h2>
    <p class="max-w-lg text-[16px] leading-relaxed text-pretty text-muted lg:pb-1">{body}</p>
  </div>
  <div class="reveal mt-10 rounded-3xl bg-cream p-5 shadow-[inset_0_0_0_1px_var(--color-line)] sm:p-8 lg:mt-12 lg:p-12">
    <!-- the visual: tiles in bg-paper shadow-card, the highlighted one bg-accent text-paper -->
  </div>
  <ul class="mt-10 grid gap-x-8 gap-y-6 sm:grid-cols-3">
    {points.map((p) => <li class="border-l-2 border-line pl-4 text-[14px] leading-relaxed text-pretty text-muted">{p}</li>)}
  </ul>
</section>
```

## 3. Chain / flow diagram

Text left, cards stepping right down a vertical hairline on the right.

```astro
<section class="border-y border-line bg-cream">
  <div class="mx-auto grid max-w-[1120px] gap-x-16 gap-y-12 px-6 py-20 lg:grid-cols-[1fr_1.05fr] lg:py-28">
    <div><!-- h2, body, check list with Icon in text-second-text --></div>
    <ol class="reveal relative flex flex-col gap-4 lg:pt-2">
      <span class="absolute bottom-16 left-7 top-8 w-px bg-line" aria-hidden="true"></span>
      <li class:list={[card, "relative min-w-0 p-5 opacity-70"]}>...</li>
      <li class:list={[card, "relative min-w-0 p-5 lg:ml-8"]}>...</li>
      <li class:list={[card, "relative p-5 lg:ml-16"]}>...</li>
    </ol>
  </div>
</section>
```

## 4. Centered flow

```astro
<section class="mx-auto max-w-[1120px] px-6 py-20 text-center lg:py-28">
  <h2 class:list={[h2, "mx-auto max-w-2xl"]}>{title}</h2>
  <p class="mx-auto mt-5 max-w-2xl text-[16px] leading-relaxed text-pretty text-muted">{body}</p>
  <div class="reveal mx-auto mt-12 grid max-w-3xl items-center gap-3 text-left sm:grid-cols-[1fr_auto_1fr]">
    <div class:list={[card, "p-5"]}>source</div>
    <div class="grid place-items-center text-faint">
      <Icon icon={IconArrowRight} class="hidden size-5 sm:block" />
      <Icon icon={IconArrowDown} class="size-5 sm:hidden" />
    </div>
    <div class:list={[card, "p-5 shadow-[0_0_0_2px_var(--color-second-text)]"]}>result</div>
  </div>
  <a href={href} class:list={[link, "mt-8"]}>{cta}</a>
</section>
```

## 5. Two-column with tilted mock

```astro
<section class="border-t border-line">
  <div class="mx-auto grid max-w-[1120px] items-center gap-x-16 gap-y-12 px-6 py-20 lg:grid-cols-[0.85fr_1.15fr] lg:py-28">
    <div class="reveal order-2 lg:order-1">
      <div class:list={[card, "mx-auto max-w-sm p-6 lg:-rotate-2"]}><!-- what the customer sees --></div>
    </div>
    <div class="order-1 lg:order-2">
      <h2 class:list={[h2, "max-w-lg"]}>{title}</h2>
      <p class="mt-5 max-w-xl text-[16px] leading-relaxed text-pretty text-muted">{body}</p>
      <ul class="mt-8 grid gap-3 sm:grid-cols-2">
        {points.map((p) => <li class="rounded-2xl bg-cream p-4 text-[14px] leading-relaxed text-pretty text-muted">{p}</li>)}
      </ul>
    </div>
  </div>
</section>
```

Tilt is static (`-rotate-2`), desktop only, never animated on hover.

## 6. Ruled grid with shared borders

Cells share 1px borders (`gap-px` over a `bg-line` parent) instead of floating as cards.

```astro
<ul class="reveal mt-12 grid gap-px overflow-hidden rounded-3xl bg-line shadow-[0_0_0_1px_var(--color-line)] sm:grid-cols-2 lg:grid-cols-3">
  {items.map((item) => (
    <li class="bg-paper p-6 lg:p-7">
      <Icon icon={icons[item.icon]} class="size-[22px] text-second-text" />
      <h3 class="mt-4 font-heading text-[16px] font-bold">{item.title}</h3>
      <p class="mt-2 text-[14px] leading-relaxed text-pretty text-muted">{item.body}</p>
    </li>
  ))}
</ul>
```

Map CMS icon keys through a fixed object so copy can't pick an icon the page doesn't ship.

## 7. Inverted band callout

```astro
<section class="bg-band text-band-fg">
  <div class="mx-auto grid max-w-[1120px] gap-x-16 gap-y-6 px-6 py-20 lg:grid-cols-2 lg:py-24">
    <h2 class:list={[h2, "max-w-md"]}>{title}</h2>
    <div>
      <p class="text-[16px] leading-relaxed text-pretty text-band-fg/75">{body}</p>
      <a href={signup} class:list={[btn, "mt-8 px-6 py-3 text-[15px]"]}>{cta}</a>
    </div>
  </div>
</section>
```

One per page at most.

## 8. Ruled pricing table, tinted featured column

One panel split into columns, not three floating cards. Only the featured
column carries the CTA.

```astro
<div class="reveal mt-12 grid overflow-hidden rounded-3xl bg-paper shadow-[0_0_0_1px_var(--color-line)] max-md:divide-y max-md:divide-line md:grid-cols-3 md:divide-x md:divide-line">
  {plans.map((plan) => (
    <div class:list={["flex flex-col p-6 lg:p-8", plan.featured && "bg-accent-tint/50"]}>
      <div class="flex min-h-6 items-center justify-between gap-3">
        <h3 class="font-heading text-[16px] font-bold">{plan.name}</h3>
        {plan.tag && <span class:list={[pill, plan.tagTone]}>{plan.tag}</span>}
      </div>
      <p class="mt-6 font-heading text-[44px] font-extrabold leading-none tracking-[-0.02em] tabular-nums">
        {plan.price}<span class="ml-0.5 text-[15px] font-semibold tracking-normal text-faint">/mo</span>
      </p>
      <p class="mt-2 min-h-5 text-[13px] text-faint">{plan.sub}</p>
      <p class="mt-5 text-[14px] leading-relaxed text-muted">{plan.desc}</p>
      {plan.featured && <a href={signup} class:list={[btn, "mt-auto w-full px-5 py-3 text-[14px] max-md:mt-6 md:mt-8"]}>{cta}</a>}
    </div>
  ))}
</div>
```

## 9. Stage track roadmap

```astro
<div class="mt-12 grid gap-10 md:grid-cols-[1.4fr_1fr_1fr] md:gap-8">
  {stages.map(({ col, bar, dot }) => (  // bar/dot: bg-ok, bg-accent, bg-line/bg-faint
    <div>
      <div class:list={["h-1 rounded-full", bar]} aria-hidden="true" />
      <h3 class="mt-5 flex items-center gap-2 font-heading text-[15px] font-bold">
        <span class={`size-2 rounded-full ${dot}`} aria-hidden="true" />{col.title}
      </h3>
      <ul class="mt-4 flex flex-col gap-2.5 text-[14px] leading-snug text-muted">
        {col.items.map((i) => <li>{i}</li>)}
      </ul>
    </div>
  ))}
</div>
```

## 10. Sticky-heading FAQ with rotating plus

Native `<details>`, animated by the `::details-content` CSS in tokens.md.

```astro
<div class="mx-auto grid max-w-[1120px] gap-x-16 gap-y-8 px-6 py-20 lg:grid-cols-[1fr_1.6fr] lg:py-28">
  <h2 class:list={[h2, "lg:sticky lg:top-28 lg:self-start"]}>{title}</h2>
  <div class="divide-y divide-line border-y border-line">
    {items.map((item) => (
      <details class="group">
        <summary class="flex cursor-pointer list-none items-center justify-between gap-4 py-5 font-heading text-[16px] font-semibold hover:text-accent-text [&::-webkit-details-marker]:hidden">
          {item.q}
          <Icon icon={IconPlus} class="size-[18px] shrink-0 text-faint transition-transform duration-200 ease-out group-open:rotate-45" />
        </summary>
        <p class="max-w-2xl pb-5 text-[15px] leading-relaxed text-pretty text-muted">{item.a}</p>
      </details>
    ))}
  </div>
</div>
```

## 11. Closing CTA band with brand mark

```astro
<section class="border-t border-line bg-cream">
  <div class="mx-auto flex max-w-[1120px] flex-col items-center px-6 pb-24 pt-20 text-center lg:pt-24">
    <BrandMark class="h-12 w-auto" />
    <h2 class:list={[h2, "mt-8 max-w-2xl sm:text-[44px]"]}>{title}</h2>
    <a href={signup} class:list={[btn, "mt-9 px-8 py-3.5 text-[15px]"]}>{cta}</a>
    <p class="mt-4 text-[13px] text-faint">{note}</p>
  </div>
</section>
```

## Secondary pages

Partner or feature landing pages (for example a Stripe integration page) reuse
the same patterns in a shorter run: hero with the flow it promises on the
right, a statement paragraph, a stage track for "how it works", a split header,
then the closing CTA band.
