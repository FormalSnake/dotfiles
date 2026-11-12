#!/bin/sh
# greetd's initial_session at boot, through session-switch-login: the host's default session
# (sessions.star) locked before its first output, the shell finding the marker and taking the lock
# over the splash's finished frame (FormalShell's 2026-10-30-locked-login.md). Hyprland locks with
# --locked-cmd, which starts the shell; formalwm with --locked, and starts it itself. The picture
# is picked as the greeter session script picks its own.
case "${XDG_RUNTIME_DIR:-}" in
  /*) runtime=$XDG_RUNTIME_DIR session=yes ;;
  *) runtime=/tmp/formalshell-$(id -u) session= ;;
esac
mkdir -p "$runtime/formalshell"
picture=
for c in /sys/class/drm/card*-*; do
  [ "$(cat "$c/status" 2>/dev/null)" = connected ] || continue
  h=$(head -n 1 "$c/modes"); h=${h#*x}; s=$((h / 500))
  [ "$s" -lt 1 ] && s=1; [ "$s" -gt 4 ] && s=4
  splash=/usr/share/formalboot/greeter-$s.png
  [ -f "$splash" ] && picture=$splash
  break
done
printf '%s' "$picture" > "$runtime/formalshell/login-lock"
# This script runs the command the boot lock leaves, so it takes one only
# from a session runtime dir no other user can reach, never the /tmp fallback.
private() {
  [ -d "$1" ] && [ ! -L "$1" ] && [ -O "$1" ] &&
    case $(stat -c %a "$1") in *00) ;; *) false ;; esac
}
next=
if [ -n "$session" ] && private "$runtime" && [ ! -L "$runtime/formalshell" ]; then
  chmod 700 "$runtime/formalshell"
  next=$runtime/formalshell/login-session
  rm -f "$next" && [ ! -e "$next" ] && [ ! -L "$next" ] || next=
fi
if [ "$(cat /etc/formalshell-greeter/default-session 2>/dev/null)" = formalwm-uwsm ]; then
  /usr/bin/uwsm start -g -1 -e -D ShojiWM -- formalwm.desktop --locked
else
  /usr/bin/uwsm start -g -1 -e -D Hyprland -- hyprland.desktop -- --locked-cmd 'systemctl --user import-environment WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP XDG_SESSION_TYPE && systemctl --user start formalshell.service'
fi
status=$?
# The boot lock leaves the session picked on it once the password has been
# checked, then ends the compositor: its environment a line each, then its command.
[ -n "$next" ] && private "$runtime" && private "$runtime/formalshell" &&
  [ -f "$next" ] && [ ! -L "$next" ] && [ -O "$next" ] || exit "$status"
command=
while IFS= read -r line; do
  case $line in
    XDG_SESSION_TYPE=* | XDG_SESSION_DESKTOP=* | XDG_CURRENT_DESKTOP=*) export "$line" ;;
    *) command=$line ;;
  esac
done < "$next"
rm -f "$next" && [ ! -e "$next" ] && [ -n "$command" ] || exit "$status"
exec sh -c "$command"
