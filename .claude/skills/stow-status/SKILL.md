---
name: stow-status
description: Inspect GNU Stow package status in formalconf. Lists config packages, checks what is stowed to the home directory, and shows app integration points with the theme system.
---

# Stow Status

Inspect GNU Stow configuration packages managed by formalconf.

## How Stow Works in Formalconf

GNU Stow creates symlinks from `~/.config/formalconf/configs/<package>/` into `$HOME`. Each package directory mirrors the home directory structure.

Example: `configs/fish/.config/fish/config.fish` → symlinked to `~/.config/fish/config.fish`

## Instructions

### Listing Packages

Read the directory listing of `~/.config/formalconf/configs/`. Each subdirectory is a stow package.

Known packages: aerospace, btop, eww, fastfetch, fish, ghostty, git, hypr, lynk-browser, mako, neovim, rift, tmux, walker, waybar

### Checking Stow Status

For each package:
1. List the top-level entries in `configs/<package>/`
2. Check if `$HOME/<entry>` exists and is a symlink
3. If the symlink target contains the package's config directory path, it is stowed

### Showing Package Contents

Recursively list `configs/<package>/` to show what config files the package manages.

### Theme Integration Points

Some stow packages source theme files from `~/.config/formalconf/current/theme/`:

| Package | How it sources the theme |
|---------|------------------------|
| ghostty | `config-file = ?"~/.config/formalconf/current/theme/ghostty.conf"` in config |
| hypr | `source = ~/.config/formalconf/current/theme/hyprland.conf` in hyprland.conf |
| neovim | LazyVim plugin config sourced from `current/theme/neovim.lua` |
| waybar | Style from `current/theme/waybar-dark.css` or `waybar-light.css` |
| mako | Theme from `current/theme/mako.ini` |
| walker | CSS from `current/theme/walker.css` |

Theme files in `current/theme/` are generated from templates, not managed by stow.

### Platform Notes

- **macOS**: aerospace, ghostty, fish, git, neovim, tmux, rift, fastfetch
- **Linux**: hypr, mako, walker, waybar, eww, btop (plus shared ones)
- Stow target is always `$HOME`, stow directory is `~/.config/formalconf/configs/`

## Constraints

- Do NOT run stow commands or formalconf CLI
- Only read and inspect the configs/ directory structure and symlinks in $HOME
