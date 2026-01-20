#!/usr/bin/env bash
# Formalconf hook: Reload Hyprland and Waybar on theme change

# Only run on Linux
[[ "$(uname -s)" != "Linux" ]] && exit 0

# Reload Hyprland configuration
hyprctl reload 2>/dev/null

# Toggle DPMS to force display re-init (fixes FreeSync flickering)
sleep 0.3
hyprctl dispatch dpms off
sleep 0.5
hyprctl dispatch dpms on

# Restart Waybar via Hyprland dispatch
pkill waybar && hyprctl dispatch exec waybar

# Reload mako notifications
makoctl reload 2>/dev/null

exit 0
