#!/bin/sh
# formalwm on the VM's display, as desktop.sh runs Hyprland: uwsm and the real hosts' formalwm.desktop,
# software GL, logind's seat, the VM's own card rather than the smoke rig's vkms one. Arguments go
# to formalwm-session (`--locked` from formalshell-login.sh).
card=
for c in /sys/class/drm/card*; do
  case ${c##*/} in *-*) continue ;; esac
  case $(readlink -f "$c"/device) in */vkms*) continue ;; esac
  card=/dev/dri/${c##*/}
  break
done
[ -n "$card" ] && export SHOJI_TTY_DRM_DEVICE=$card
export LIBSEAT_BACKEND=logind LIBGL_ALWAYS_SOFTWARE=1 XDG_SESSION_TYPE=wayland
exec uwsm start -e -D ShojiWM -- formalwm.desktop "$@"
