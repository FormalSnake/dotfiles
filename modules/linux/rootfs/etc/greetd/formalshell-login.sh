#!/bin/sh
# greetd's initial_session at boot, through session-switch-login: Hyprland locked before its first
# output (--locked-cmd), its locked command starting the shell, which finds the marker and takes
# the lock over the splash's finished frame (FormalShell's 2026-10-30-locked-login.md). The
# picture is picked as the greeter session script picks its own.
mkdir -p "$XDG_RUNTIME_DIR/formalshell"
picture=
for c in /sys/class/drm/card*-*; do
  [ "$(cat "$c/status" 2>/dev/null)" = connected ] || continue
  h=$(head -n 1 "$c/modes"); h=${h#*x}; s=$((h / 500))
  [ "$s" -lt 1 ] && s=1; [ "$s" -gt 4 ] && s=4
  splash=/usr/share/plymouth/themes/formalos/greeter-$s.png
  [ -f "$splash" ] && picture=$splash
  break
done
printf '%s' "$picture" > "$XDG_RUNTIME_DIR/formalshell/login-lock"
exec /usr/bin/uwsm start -e -D Hyprland -- hyprland.desktop -- --locked-cmd 'systemctl --user import-environment WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP XDG_SESSION_TYPE && systemctl --user start formalshell.service'
