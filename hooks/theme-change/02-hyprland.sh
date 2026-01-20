#!/usr/bin/env bash
# Formalconf hook: Reload Hyprland and Waybar on theme change

# Only run on Linux
[[ "$(uname -s)" != "Linux" ]] && exit 0

# Reload Hyprland configuration
hyprctl reload 2>/dev/null

# Restart Waybar via Hyprland dispatch
pkill waybar && hyprctl dispatch exec waybar

exit 0
