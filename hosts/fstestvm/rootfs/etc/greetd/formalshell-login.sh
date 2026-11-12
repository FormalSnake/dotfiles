#!/bin/sh
# The real hosts' locked login (modules/linux/rootfs/etc/greetd/formalshell-login.sh) on the VM's
# display, started as desktop.sh starts a greeter login: software GL, logind's seat, the VM's
# own card rather than the smoke rig's vkms one.
card=
for c in /sys/class/drm/card*; do
  case ${c##*/} in *-*) continue ;; esac
  case $(readlink -f "$c"/device) in */vkms*) continue ;; esac
  card=/dev/dri/${c##*/}
  break
done
[ -n "$card" ] && export AQ_DRM_DEVICES=$card
export LIBSEAT_BACKEND=logind LIBGL_ALWAYS_SOFTWARE=1
case "${XDG_RUNTIME_DIR:-}" in
  /*) runtime=$XDG_RUNTIME_DIR session=yes ;;
  *) runtime=/tmp/formalshell-$(id -u) session= ;;
esac
mkdir -p "$runtime/formalshell"
picture=
for c in /sys/class/drm/card*-*; do
  case $(readlink -f "$c"/device) in */vkms*) continue ;; esac
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
# The slot's default session (host.star), formalwm started locked as on the real hosts.
if [ "$(cat /etc/fstestvm/default-session 2>/dev/null)" = formalwm ]; then
  /etc/fstestvm/formalwm.sh --locked
else
  uwsm start -g -1 -e -D Hyprland -- hyprland.desktop -- --config /etc/fstestvm/hyprland.lua --locked-cmd 'systemctl --user import-environment WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP XDG_SESSION_TYPE && systemctl --user start formalshell.service'
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
