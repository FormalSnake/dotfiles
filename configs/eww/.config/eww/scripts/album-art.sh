#!/bin/bash
# Downloads and caches Spotify album art, outputs local path

CACHE_DIR="$HOME/.cache/eww-spotify"
DEFAULT_ART="$HOME/.config/eww/assets/default-album.svg"

mkdir -p "$CACHE_DIR"

get_art() {
    local art_url
    art_url=$(playerctl -p spotify metadata mpris:artUrl 2>/dev/null)

    if [[ -z "$art_url" ]]; then
        echo "$DEFAULT_ART"
        exit 0
    fi

    # Create filename from URL hash
    local hash
    hash=$(echo "$art_url" | md5sum | cut -d' ' -f1)
    local cached_file="$CACHE_DIR/$hash.png"

    # Return cached file if exists
    if [[ -f "$cached_file" ]]; then
        echo "$cached_file"
        exit 0
    fi

    # Download and cache the album art
    if curl -s -o "$cached_file" "$art_url" 2>/dev/null; then
        echo "$cached_file"
    else
        echo "$DEFAULT_ART"
    fi
}

# Clean old cache files (older than 7 days)
find "$CACHE_DIR" -type f -mtime +7 -delete 2>/dev/null

get_art
