---
name: system-overview
description: Formalconf dotfiles/theme system architecture, data flow, key directories, and AI restrictions. Provides background context for working in this repo.
user-invocable: false
---

# Formalconf System Overview

## Architecture

Formalconf is a dotfiles/theme management system with two parts:

1. **User config repo** (`~/.config/formalconf/`) — themes, templates, generated configs, stow packages, hooks
2. **CLI source** (`~/Developer/formalconf/`) — TypeScript/Bun/Ink TUI application (not executable by AI)

## Data Flow: Theme Application

```
User selects theme (e.g. catppuccin:dark)
  → CLI loads themes/catppuccin.json, extracts "dark" palette
  → Template engine processes each templates/*.template file
  → {{variable}} placeholders replaced with palette colors
  → Color modifiers (.strip, .rgb, .rgba, .decimal, .r/.g/.b, .red/.green/.blue) transform formats
  → Rendered files written to generated/
  → Copied to current/theme/
  → Wallpapers downloaded if configured
  → GTK/Qt themes applied (Linux)
  → hooks/theme-change/ scripts execute
  → Apps pick up new configs from current/theme/
```

## Key Directories

| Path | Purpose |
|------|---------|
| `themes/*.json` | Theme color definitions (15 themes) |
| `templates/*.template` | Template files with `{{variable}}` placeholders |
| `templates/templates.json` | Template manifest (version tracking, mode config) |
| `generated/` | Rendered output from templates |
| `current/theme/` | Active theme files (copied from generated/) |
| `current/backgrounds/` | Active wallpapers |
| `configs/` | GNU Stow packages (symlinked to $HOME) |
| `hooks/theme-change/` | Post-theme-switch scripts |
| `scripts/` | Utility scripts (wallpaper cycling, screenshots, etc.) |
| `theme-config.json` | Device-to-theme mappings |
| `pkg-config.json` | Cross-platform package manifest |

## Theme JSON Structure

Themes contain: `title` (required), optional `description`/`author`/`version`/`source`, one or both of `dark`/`light` palettes (each with 16 ANSI colors + background/foreground/cursor + optional selection/accent/border), optional `neovim` (repo + colorscheme), `gtk` (Colloid variant/tweaks or pre-built overrides), and `wallpapers` (dark/light URL arrays).

## Template Types

- **Single-mode** (default): One output per active mode (e.g., `alacritty.toml.template`)
- **Partial-mode**: Separate dark/light files detected by `-dark.`/`-light.` in filename (e.g., `kitty-dark.conf.template`)
- **Dual-mode**: Access both palettes via `dark.*`/`light.*` prefixes, set `"mode": "dual"` in manifest (ghostty.conf, neovim.lua, lynk.css)

## Stow System

GNU Stow symlinks files from `configs/<package>/` into `$HOME`. Each package mirrors the home directory tree. Apps source theme files from `~/.config/formalconf/current/theme/` (e.g., Hyprland: `source = ~/.config/formalconf/current/theme/hyprland.conf`).

## Available Themes

catppuccin, ethereal, everforest, flexoki, gruvbox, hackerman, kanagawa, matte-black, nord, orng, osaka-jade, ristretto, rose-pine, tokyo-night, vesper

## AI Restrictions

The AI CANNOT execute the formalconf CLI. No theme switching, stow management, or package sync. The AI CAN read/edit theme JSON files, template files, stow package configs, hook scripts, and inspect directory structures.
