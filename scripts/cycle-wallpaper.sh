#!/usr/bin/env bash
# Cycle through wallpapers in current/backgrounds

BACKGROUNDS_DIR="$HOME/.config/formalconf/current/backgrounds"
INDEX_FILE="/tmp/formalconf-wp-idx"

# Get sorted list of wallpaper files
mapfile -t FILES < <(find "$BACKGROUNDS_DIR" -maxdepth 1 -type f | sort)

# Exit if no wallpapers
[[ ${#FILES[@]} -eq 0 ]] && exit 1

# Read current index (default -1 so first run gives index 0)
IDX=$(cat "$INDEX_FILE" 2>/dev/null || echo -1)

# Increment and wrap
IDX=$(( (IDX + 1) % ${#FILES[@]} ))

# Save index and set wallpaper
echo "$IDX" > "$INDEX_FILE"
awww img "${FILES[$IDX]}"
