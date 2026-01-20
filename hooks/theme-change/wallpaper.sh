#!/usr/bin/env bash
# Formalconf hook: Set random wallpaper on theme change

BACKGROUNDS_DIR="$HOME/.config/formalconf/current/backgrounds"

# Get all wallpaper files
mapfile -t FILES < <(find -L "$BACKGROUNDS_DIR" -maxdepth 1 -type f 2>/dev/null)

# Exit if no wallpapers found
[[ ${#FILES[@]} -eq 0 ]] && exit 0

# Pick a random wallpaper
RANDOM_IDX=$((RANDOM % ${#FILES[@]}))
WALLPAPER="${FILES[$RANDOM_IDX]}"

# Set wallpaper based on platform
case "$(uname -s)" in
  Linux)
    # Linux: use awww (Wayland wallpaper daemon)
    awww img "$WALLPAPER"
    ;;
  *)
    # macOS and other platforms: do nothing
    exit 0
    ;;
esac
