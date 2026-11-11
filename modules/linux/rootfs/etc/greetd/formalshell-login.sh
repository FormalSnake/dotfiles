#!/bin/sh
# greetd's initial_session at boot, through session-switch-login: the host's default session
# (sessions.star) locked before its first output, the shell finding the marker and taking the lock
# over the splash's finished frame (FormalShell's 2026-10-30-locked-login.md). Hyprland locks with
# --locked-cmd, which starts the shell; formalwm with --locked, and starts it itself. The picture
# is picked as the greeter session script picks its own.
mkdir -p "$XDG_RUNTIME_DIR/formalshell"
picture=
for c in /sys/class/drm/card*-*; do
  [ "$(cat "$c/status" 2>/dev/null)" = connected ] || continue
  h=$(head -n 1 "$c/modes"); h=${h#*x}; s=$((h / 500))
  [ "$s" -lt 1 ] && s=1; [ "$s" -gt 4 ] && s=4
  splash=/usr/share/formalboot/greeter-$s.png
  [ -f "$splash" ] && picture=$splash
  break
done
printf '%s' "$picture" > "$XDG_RUNTIME_DIR/formalshell/login-lock"
if [ "$(cat /etc/formalshell-greeter/default-session 2>/dev/null)" = formalwm-uwsm ]; then
  exec /usr/bin/uwsm start -g -1 -e -D ShojiWM -- formalwm.desktop --locked
fi
exec /usr/bin/uwsm start -g -1 -e -D Hyprland -- hyprland.desktop -- --locked-cmd 'systemctl --user import-environment WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP XDG_SESSION_TYPE && systemctl --user start formalshell.service'
