# Icons: Nucleo

Our icon set is Nucleo. Never Lucide (including `@lucide/astro` or shadcn's
default `lucide-react`), never hand-written `<svg>` paths.

## Packages

| Package | Use for |
| --- | --- |
| `nucleo-ui-fill-duo-18` | Default UI icon: nav, feature grids, cards, buttons. Duo-tone. |
| `nucleo-ui-outline-18` | Quieter inline icons next to text, list checks, arrows |
| `nucleo-core-outline-24` | Larger feature or illustration-size icons |
| `nucleo-micro-bold` | 12 to 14px icons inside pills, badges, dense tables |
| `nucleo-flags` | Country flags (language and country pickers, analytics tables) |

Each package exports React components named `Icon<Name><Style><Size>`, for
example `IconGlobeFillDuo18`, `IconChartActivityFillDuo18`,
`IconCircleCheckFillDuo18`. Import by name:

```tsx
import { IconCopyFillDuo18, IconCircleCheckFillDuo18 } from "nucleo-ui-fill-duo-18";
```

Pick one family per surface and stay in it. Size with `size-*` utilities,
colour with `text-*` (icons use `currentColor`). One colour for a whole grid.

### Duo-tone CSS

Duo icons mark their secondary layer with `data-color="color-2"`. Add once to
the global stylesheet:

```css
.duo-icon [data-color="color-2"] {
  fill: var(--duo-icon-secondary, currentColor);
  fill-opacity: 0.35;
}
```

## React apps

Use the components directly; add `className="duo-icon ..."` on duo icons, or
wrap them in a small `DuoIcon` component that does it. If the project uses
shadcn, `components.json` may keep `iconLibrary: "lucide"` because the CLI
rejects `nucleo`; replace every Lucide import the generator adds.

## Astro sites without React

Don't add `@astrojs/react` just for icons (it pulls in client tooling and can
fight the Vite version Astro pins). Render the React component to inline SVG at
build time instead, with `react` and `react-dom` as plain dependencies:

```astro
---
// src/components/Icon.astro: static Nucleo SVG, no client JS.
import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";

const { icon, class: className } = Astro.props;
const svg = renderToStaticMarkup(
  createElement(icon, {
    className: className ? `duo-icon ${className}` : "duo-icon",
    "aria-hidden": true,
  }),
);
---

<Fragment set:html={svg} />
```

```astro
---
import { IconGlobeFillDuo18 } from "nucleo-ui-fill-duo-18";
import Icon from "../components/Icon.astro";
---
<Icon icon={IconGlobeFillDuo18} class="size-4 text-muted" />
```

Works the same inside Starlight component overrides and `.mdx` pages.
Decorative icons stay `aria-hidden`; an icon-only control gets an
`aria-label` on the control, not on the SVG.

## Licence key

The Nucleo packages run a `preinstall` check (`account-check.js`) that reads
`NUCLEO_LICENSE_KEY` from the environment and validates it against
nucleoapp.com. Nucleo's licence forbids sharing login details, so the key is
personal:

1. Get access through the CanaryCoders Nucleo Team License (ask whoever
   manages it to add you), or use your own Nucleo seat.
2. Export your own key in your shell profile: `export NUCLEO_LICENSE_KEY=...`.
   Never put it in `.npmrc`, a committed `.env`, a lockfile or a script. A
   gitignored local `.env` is fine; ship an `.env.example` with
   `NUCLEO_LICENSE_KEY=` empty.
3. CI (GitHub Actions): a repo secret `NUCLEO_LICENSE_KEY`, passed as `env:` on
   the install step only.
4. Cloudflare Workers Builds / Pages: a secret build variable
   `NUCLEO_LICENSE_KEY` on the project, so the build's `bun install` passes.

## Finding icons

Optional: if you installed Nucleo's own skills bundle and MCP server from the
Nucleo app (per licensed user, lives under `~/.nucleo/`), search with the
`nucleo-icons` MCP: `nucleo_list_families` to pick the family,
`nucleo_search_icons` with a plain word ("globe", "invoice", "chevron"), then
`nucleo_get_icon` for the exact export name. Without it, search the package's
type declarations: `rg -o 'Icon\w+FillDuo18' node_modules/nucleo-ui-fill-duo-18 | sort -u | rg -i globe`.

## Troubleshooting

| Symptom | Cause and fix |
| --- | --- |
| `bun install` / `npm install` fails with "Nucleo license key has not been set" | `NUCLEO_LICENSE_KEY` is not in the environment of the install process. Export it in your shell, or add it as a secret build variable in CI or Workers Builds. |
| Install works locally, fails in CI | Secret missing or not passed to the install step's `env:`. |
| Licence check rejects a key that was valid | Seat removed from the team licence, or the key was rotated. Get a fresh key from your Nucleo account. |
| Duo icon renders flat, one colour | Missing `duo-icon` class or the `[data-color="color-2"]` CSS. |
| shadcn add brought in `lucide-react` | Generator default. Swap the import for the Nucleo equivalent and remove the dependency. |
