---
name: edit-theme
description: Guide for editing or creating formalconf theme JSON files. Includes the full schema, required fields, color format rules, neovim/GTK config, and a validation checklist.
argument-hint: "[theme-name]"
---

# Edit Theme

Guide for editing or creating theme JSON files in `~/.config/formalconf/themes/`.

## Full Theme JSON Schema

```json
{
  "title": "Theme Name",
  "description": "Optional description",
  "author": "Optional author",
  "version": "1.0.0",
  "source": "https://optional-url",
  "dark": { /* ThemeColorPalette */ },
  "light": { /* ThemeColorPalette */ },
  "neovim": {
    "repo": "author/nvim-plugin",
    "colorscheme": "dark-colorscheme-name",
    "light_colorscheme": "optional-light-variant",
    "opts": {}
  },
  "gtk": {
    "variant": "default",
    "tweaks": ["rimless", "black"],
    "override": {
      "dark": "override-dir-name",
      "light": "override-dir-name"
    }
  },
  "wallpapers": {
    "dark": ["https://url1", "https://url2"],
    "light": ["https://url3"]
  }
}
```

## ThemeColorPalette (required fields)

Every palette MUST include all of these:

```json
{
  "color0": "#hex",  "color1": "#hex",  "color2": "#hex",  "color3": "#hex",
  "color4": "#hex",  "color5": "#hex",  "color6": "#hex",  "color7": "#hex",
  "color8": "#hex",  "color9": "#hex",  "color10": "#hex", "color11": "#hex",
  "color12": "#hex", "color13": "#hex", "color14": "#hex", "color15": "#hex",
  "background": "#hex",
  "foreground": "#hex",
  "cursor": "#hex"
}
```

Optional palette fields:
```json
{
  "selection_background": "#hex",
  "selection_foreground": "#hex",
  "accent": "#hex",
  "border": "#hex"
}
```

## ANSI Color Conventions

| Index | Normal | Bright (8+) |
|-------|--------|-------------|
| 0/8 | Black | Bright Black (gray) |
| 1/9 | Red | Bright Red |
| 2/10 | Green | Bright Green |
| 3/11 | Yellow | Bright Yellow |
| 4/12 | Blue | Bright Blue |
| 5/13 | Magenta | Bright Magenta |
| 6/14 | Cyan | Bright Cyan |
| 7/15 | White | Bright White |

## Color Format Rules

- All colors MUST be hex format: `#RRGGBB` (6-digit) or `#RGB` (3-digit)
- The `#` prefix is required
- The template engine normalizes to uppercase 6-digit internally
- Colors are automatically converted to: hex, strip (no #), rgb(), rgba(), decimal, individual r/g/b (0-255), and float r/g/b (0.0-1.0)

## Neovim Config

Required fields when `neovim` is present: `repo` (plugin repository), `colorscheme` (dark mode name).
Optional: `light_colorscheme` (light mode variant), `opts` (plugin setup options).

## GTK Config

Uses the Colloid GTK theme system:
- `variant` — Colloid color variant (default, purple, pink, red, orange, yellow, green, teal, grey)
- `tweaks` — array of Colloid tweaks (rimless, black, float, outline)
- `override` — use pre-built themes from `gtk/overrides/` instead of building Colloid

## Wallpapers

- `dark` — array of URLs (required if `wallpapers` section exists)
- `light` — array of URLs (optional, falls back to dark)

## Validation Checklist

After editing, verify:
1. Valid JSON (no trailing commas, proper quoting)
2. `title` field exists and is a non-empty string
3. At least one of `dark` or `light` palette exists
4. Every palette has all 16 ANSI colors (color0-color15) plus background, foreground, cursor
5. All color values match `#[0-9A-Fa-f]{3,6}` pattern
6. If `neovim` exists: `repo` and `colorscheme` are required strings
7. If `wallpapers` exists: `dark` array is required

## Creating a New Theme

1. Filename: `~/.config/formalconf/themes/<name>.json` (lowercase, hyphens for spaces)
2. At minimum: title + one palette (dark recommended)
3. Use an existing theme as reference (e.g., `catppuccin.json` for full example)
4. After creating, user must run `formalconf theme <name>:dark` to apply

## Constraints

- Do NOT run formalconf CLI commands to apply themes
- After edits, remind user to re-apply their theme via the CLI
