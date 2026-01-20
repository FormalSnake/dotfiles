#!/usr/bin/env bash
# Formalconf hook: Apply GTK theme on theme change

# Only run on Linux
[[ "$(uname -s)" != "Linux" ]] && exit 0

# Only run if GTK theme was generated
[[ -z "$FORMALCONF_GTK_THEME" ]] && exit 0

# Apply GTK3 theme via gsettings
gsettings set org.gnome.desktop.interface gtk-theme "$FORMALCONF_GTK_THEME" 2>/dev/null
gsettings set org.gnome.desktop.interface color-scheme "prefer-${FORMALCONF_THEME_MODE}" 2>/dev/null

# Apply libadwaita/GTK4 theme using Colloid
COLLOID_DIR="$HOME/.config/formalconf/gtk/colloid-gtk-theme"
[[ ! -d "$COLLOID_DIR" ]] && exit 0

# Determine color scheme from FORMALCONF_THEME_NAME or infer from GTK theme
THEME_NAME="${FORMALCONF_THEME_NAME:-}"
if [[ -z "$THEME_NAME" ]]; then
  # Try to infer from GTK theme name (e.g., "Colloid-Dark-Catppuccin" -> "catppuccin")
  THEME_NAME=$(echo "$FORMALCONF_GTK_THEME" | tr '[:upper:]' '[:lower:]')
fi

# Map to Colloid color scheme
TWEAKS=""
case "$THEME_NAME" in
  *catppuccin*) TWEAKS="catppuccin" ;;
  *gruvbox*)    TWEAKS="gruvbox" ;;
  *everforest*) TWEAKS="everforest" ;;
  *nord*)       TWEAKS="nord" ;;
  *dracula*)    TWEAKS="dracula" ;;
esac

# Determine color variant
COLOR_OPT=""
if [[ "$FORMALCONF_THEME_MODE" == "dark" ]]; then
  COLOR_OPT="-c Dark"
else
  COLOR_OPT="-c Light"
fi

# Regenerate libadwaita CSS (suppress output)
if [[ -n "$TWEAKS" ]]; then
  "$COLLOID_DIR/install.sh" -l --tweaks "$TWEAKS" $COLOR_OPT >/dev/null 2>&1 &
else
  "$COLLOID_DIR/install.sh" -l $COLOR_OPT >/dev/null 2>&1 &
fi
