#!/usr/bin/env bash
# Toggle workspace gaps between normal and zero

GAPFILE="/tmp/formalconf-gaps-state"

if [[ -f "$GAPFILE" ]]; then
    # Restore normal gaps
    hyprctl keyword general:gaps_in 8
    hyprctl keyword general:gaps_out 16
    rm -f "$GAPFILE"
else
    # Remove gaps
    hyprctl keyword general:gaps_in 0
    hyprctl keyword general:gaps_out 0
    touch "$GAPFILE"
fi
