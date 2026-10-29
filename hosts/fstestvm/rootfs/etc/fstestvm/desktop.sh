#!/bin/sh
# What the greeter starts on a login: Hyprland on the VM's display, in software, running the shell
# as the owner's session does. vkms is the smoke rig's card.
card=
for c in /sys/class/drm/card*; do
  case ${c##*/} in *-*) continue ;; esac
  case $(readlink -f "$c/device/driver") in */virtio_gpu) card=/dev/dri/${c##*/}; break ;; esac
done
[ -n "$card" ] && export AQ_DRM_DEVICES=$card
export LIBGL_ALWAYS_SOFTWARE=1 XDG_SESSION_TYPE=wayland XDG_CURRENT_DESKTOP=Hyprland
exec Hyprland --config /etc/fstestvm/hyprland.lua
