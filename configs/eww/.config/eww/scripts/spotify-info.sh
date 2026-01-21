#!/bin/bash
# Returns JSON with Spotify metadata via playerctl

get_metadata() {
    local player="spotify"

    # Check if spotify is running
    if ! playerctl -p "$player" status &>/dev/null; then
        echo '{"status":"stopped","title":"","artist":"","album":"","art_url":"","position":0,"length":0}'
        exit 0
    fi

    status=$(playerctl -p "$player" status 2>/dev/null || echo "stopped")
    title=$(playerctl -p "$player" metadata title 2>/dev/null || echo "")
    artist=$(playerctl -p "$player" metadata artist 2>/dev/null || echo "")
    album=$(playerctl -p "$player" metadata album 2>/dev/null || echo "")
    art_url=$(playerctl -p "$player" metadata mpris:artUrl 2>/dev/null || echo "")
    position=$(playerctl -p "$player" position 2>/dev/null || echo "0")
    length=$(playerctl -p "$player" metadata mpris:length 2>/dev/null || echo "0")

    # Convert position to microseconds using awk
    position_us=$(awk "BEGIN {printf \"%.0f\", $position * 1000000}")

    # Escape special characters for JSON
    title=$(echo "$title" | sed 's/\\/\\\\/g; s/"/\\"/g')
    artist=$(echo "$artist" | sed 's/\\/\\\\/g; s/"/\\"/g')
    album=$(echo "$album" | sed 's/\\/\\\\/g; s/"/\\"/g')

    cat <<EOF
{"status":"$status","title":"$title","artist":"$artist","album":"$album","art_url":"$art_url","position":${position_us},"length":$length}
EOF
}

get_metadata
