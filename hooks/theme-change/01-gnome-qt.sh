#!/usr/bin/env bash
# Formalconf hook: Apply GTK/GNOME/Qt theme settings on theme change

# Only run on Linux
[[ "$(uname -s)" != "Linux" ]] && exit 0

HYPRLAND_CONF="$HOME/.config/formalconf/current/theme/hyprland.conf"

# Parse color-scheme from the generated config to detect dark/light mode
if grep -q 'prefer-dark' "$HYPRLAND_CONF" 2>/dev/null; then
    COLOR_SCHEME="prefer-dark"
elif grep -q 'prefer-light' "$HYPRLAND_CONF" 2>/dev/null; then
    COLOR_SCHEME="prefer-light"
else
    COLOR_SCHEME="prefer-dark"
fi

# Apply GNOME color scheme (gsettings calls in the hyprland template handle
# gtk-theme, icon-theme, cursor-theme, cursor-size, and font — this hook
# ensures color-scheme is applied even if Hyprland hasn't reloaded yet)
gsettings set org.gnome.desktop.interface color-scheme "$COLOR_SCHEME" 2>/dev/null

# Qt is handled automatically via environment variables:
# - QT_QPA_PLATFORMTHEME=qt5ct (set in env.conf)
# - QT_STYLE_OVERRIDE=kvantum (set in env.conf)
# Configure qt5ct/qt6ct and kvantum themes via their respective config files

exit 0
