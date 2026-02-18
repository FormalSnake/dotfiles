#!/usr/bin/env bash
# Screenshot utility using grim + slurp + satty
# Usage: screenshot.sh [region|window|fullscreen]

MODE="${1:-region}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
SCREENSHOT_DIR="$HOME/Pictures/Screenshots"
mkdir -p "$SCREENSHOT_DIR"
FILE="$SCREENSHOT_DIR/screenshot-$TIMESTAMP.png"

case "$MODE" in
    region)
        grim -g "$(slurp)" - | satty --filename - --output-filename "$FILE"
        ;;
    window)
        GEOM=$(hyprctl activewindow -j | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')
        grim -g "$GEOM" - | satty --filename - --output-filename "$FILE"
        ;;
    fullscreen)
        grim - | satty --filename - --output-filename "$FILE"
        ;;
    *)
        echo "Usage: screenshot.sh [region|window|fullscreen]"
        exit 1
        ;;
esac

# Copy to clipboard if file was saved
[[ -f "$FILE" ]] && wl-copy < "$FILE" && notify-send "Screenshot saved" "$FILE"
