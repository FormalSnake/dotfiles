#!/bin/bash
# Handles progress bar data and seeking for Spotify

PLAYER="spotify"

format_time() {
    local us=$1
    local seconds=$((us / 1000000))
    local minutes=$((seconds / 60))
    local secs=$((seconds % 60))
    printf "%d:%02d" "$minutes" "$secs"
}

case "$1" in
    get)
        # Returns progress percentage (0-100)
        position=$(playerctl -p "$PLAYER" position 2>/dev/null || echo "0")
        length=$(playerctl -p "$PLAYER" metadata mpris:length 2>/dev/null || echo "1")

        if [[ "$length" -gt 0 ]]; then
            # Use awk for floating point math
            percentage=$(awk "BEGIN {printf \"%.0f\", $position * 1000000 * 100 / $length}")
            echo "$percentage"
        else
            echo "0"
        fi
        ;;

    set)
        # Seeks to position based on percentage (0-100)
        percentage=$2
        length=$(playerctl -p "$PLAYER" metadata mpris:length 2>/dev/null || echo "0")

        if [[ "$length" -gt 0 ]]; then
            # Calculate position in seconds using awk
            position=$(awk "BEGIN {printf \"%.2f\", $length * $percentage / 100 / 1000000}")
            playerctl -p "$PLAYER" position "$position" 2>/dev/null
        fi
        ;;

    format-position)
        # Returns formatted position "M:SS"
        position=$(playerctl -p "$PLAYER" position 2>/dev/null || echo "0")
        position_us=$(awk "BEGIN {printf \"%.0f\", $position * 1000000}")
        format_time "$position_us"
        ;;

    format-length)
        # Returns formatted length "M:SS"
        length=$(playerctl -p "$PLAYER" metadata mpris:length 2>/dev/null || echo "0")
        format_time "$length"
        ;;

    *)
        echo "Usage: $0 {get|set <percent>|format-position|format-length}"
        exit 1
        ;;
esac
