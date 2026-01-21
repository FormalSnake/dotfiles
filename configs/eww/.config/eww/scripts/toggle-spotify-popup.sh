#!/bin/bash
# Toggle the Spotify popup window on the active monitor

# Get active monitor ID
MONITOR=$(hyprctl activeworkspace -j | jq -r '.monitorID')

# Determine window name based on monitor
if [[ "$MONITOR" == "1" ]]; then
    WINDOW_NAME="spotify-popup-1"
    OTHER_WINDOW="spotify-popup"
else
    WINDOW_NAME="spotify-popup"
    OTHER_WINDOW="spotify-popup-1"
fi

# Close the other monitor's popup if open
eww close "$OTHER_WINDOW" 2>/dev/null

# Toggle the current monitor's popup
if eww active-windows 2>/dev/null | grep -q "$WINDOW_NAME"; then
    eww close "$WINDOW_NAME"
else
    eww open "$WINDOW_NAME"
fi
