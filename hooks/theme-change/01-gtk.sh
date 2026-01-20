#!/usr/bin/env bash
# Formalconf hook: Apply GTK theme on theme change

# Only run on Linux
[[ "$(uname -s)" != "Linux" ]] && exit 0

# Only run if GTK theme was generated
[[ -z "$FORMALCONF_GTK_THEME" ]] && exit 0

# Apply GTK theme via gsettings (for GNOME/libadwaita apps)
gsettings set org.gnome.desktop.interface gtk-theme "$FORMALCONF_GTK_THEME" 2>/dev/null

# Set color scheme preference
gsettings set org.gnome.desktop.interface color-scheme "prefer-${FORMALCONF_THEME_MODE}" 2>/dev/null
