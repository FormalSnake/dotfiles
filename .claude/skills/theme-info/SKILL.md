---
name: theme-info
description: Show details about a specific formalconf theme or list all available themes. Displays color palettes, neovim config, wallpapers, and GTK settings from theme JSON files.
argument-hint: "[theme-name]"
---

# Theme Info

Display information about formalconf themes stored in `~/.config/formalconf/themes/*.json`.

## Instructions

### Listing All Themes

Read all `.json` files in `~/.config/formalconf/themes/` and present a summary for each:

- `title` — display name
- `description` — short description
- `author` — theme author
- Whether `dark` and/or `light` palette exists
- Whether `neovim` config is present
- Number of wallpaper URLs per mode

Example format:
```
Catppuccin — Soothing pastel theme (dark + light) by Catppuccin Org
  Neovim: catppuccin/nvim (catppuccin-mocha / catppuccin-latte)
  Wallpapers: 3 dark, 1 light
```

### Showing a Specific Theme

When `$ARGUMENTS` names a theme, read `~/.config/formalconf/themes/$ARGUMENTS.json` and display:

1. **Metadata**: title, description, author, version, source URL
2. **Available Modes**: dark, light, or both
3. **Color Palette** (for each available mode):
   - ANSI colors: color0 through color15
   - Special colors: background, foreground, cursor, selection_background, selection_foreground, accent, border
   - Display hex values
4. **Neovim Integration**: repo, colorscheme, light_colorscheme (if present)
5. **GTK Config**: variant, tweaks, override dirs (if present)
6. **Wallpapers**: URLs for dark and light wallpapers (if present)

### Color Palette Reference

Required palette fields: `color0`-`color15`, `background`, `foreground`, `cursor`

Optional palette fields (have fallback defaults):
- `selection_background` → defaults to color0
- `selection_foreground` → defaults to foreground
- `accent` → defaults to color4
- `border` → defaults to color0

### ANSI Color Mapping

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

## Constraints

- Do NOT run formalconf CLI commands
- Only read theme JSON files — do not modify unless explicitly asked
- Theme files are at `~/.config/formalconf/themes/*.json`
- The active theme's rendered output is in `~/.config/formalconf/current/theme/`
