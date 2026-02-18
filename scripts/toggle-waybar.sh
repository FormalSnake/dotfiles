#!/usr/bin/env bash
# Toggle waybar visibility

if pgrep -x waybar >/dev/null; then
    pkill waybar
else
    hyprctl dispatch exec waybar
fi
