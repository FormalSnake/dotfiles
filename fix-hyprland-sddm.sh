#!/bin/bash
# Fix Hyprland SDDM login issues for CachyOS on Steam Deck (desktop use)
# Run this script with: sudo bash ~/.config/formalconf/fix-hyprland-sddm.sh

set -e

echo "=== Fixing SDDM Hyprland login issues ==="

# 1. Remove Steam-specific SDDM configs
echo "[1/4] Removing Steam-specific SDDM configs..."
rm -f /etc/sddm.conf.d/steam-deckify.conf
rm -f /etc/sddm.conf.d/zz-steamos-autologin.conf

# 2. Create clean Hyprland SDDM autologin config
echo "[2/4] Creating Hyprland autologin config..."
cat > /etc/sddm.conf.d/99-hyprland.conf << 'EOF'
[Autologin]
Session=hyprland.desktop
User=kyandesutter
Relogin=false

[General]
DisplayServer=wayland
EOF

# 3. Clean up the main sddm.conf to remove Steam autologin
echo "[3/4] Cleaning up main SDDM config..."
cat > /etc/sddm.conf << 'EOF'
[General]
HaltCommand=/usr/bin/systemctl poweroff
RebootCommand=/usr/bin/systemctl reboot

[Theme]
Current=breeze

[Users]
MaximumUid=60000
MinimumUid=1000
EOF

# 4. Fix the broken environment.d file
echo "[4/4] Fixing environment.d/handheld.conf..."
if [ -f /etc/environment.d/handheld.conf ]; then
    cat > /etc/environment.d/handheld.conf << 'EOF'
# Decky loader config (fixed syntax)
DECKY_USER="kyandesutter"
DECK_USER_HOME="/home/kyandesutter"
# Qt theme settings
QT_QUICK_CONTROLS_STYLE=org.kde.desktop
EOF
fi

echo ""
echo "=== Done! ==="
echo "Changes made:"
echo "  - Removed steam-deckify.conf and zz-steamos-autologin.conf"
echo "  - Created clean 99-hyprland.conf with autologin to Hyprland"
echo "  - Cleaned up /etc/sddm.conf"
echo "  - Fixed /etc/environment.d/handheld.conf syntax"
echo ""
echo "Please reboot to apply all changes:"
echo "  sudo reboot"
