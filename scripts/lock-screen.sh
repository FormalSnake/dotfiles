#!/usr/bin/env bash
# Lock screen with hyprlock and reset keyboard layout

# Reset to default keyboard layout before locking
hyprctl switchxkblayout all 0 2>/dev/null

hyprlock
