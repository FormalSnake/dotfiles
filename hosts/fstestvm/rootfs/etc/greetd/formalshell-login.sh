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
mkdir -p "$XDG_RUNTIME_DIR/formalshell"
picture=
for c in /sys/class/drm/card*-*; do
  case $(readlink -f "$c"/device) in */vkms*) continue ;; esac
  [ "$(cat "$c/status" 2>/dev/null)" = connected ] || continue
  h=$(head -n 1 "$c/modes"); h=${h#*x}; s=$((h / 500))
  [ "$s" -lt 1 ] && s=1; [ "$s" -gt 4 ] && s=4
  splash=/usr/share/plymouth/themes/formalos/greeter-$s.png
  [ -f "$splash" ] && picture=$splash
  break
done
printf '%s' "$picture" > "$XDG_RUNTIME_DIR/formalshell/login-lock"
exec uwsm start -g -1 -e -D Hyprland -- hyprland.desktop -- --config /etc/fstestvm/hyprland.lua --locked-cmd 'systemctl --user import-environment WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP XDG_SESSION_TYPE && systemctl --user start formalshell.service'
