#!/bin/sh
# What the greeter starts on a login: Hyprland on the VM's display, in software, running the shell
# as the owner's session does. vkms is the smoke rig's card.
card=
for c in /sys/class/drm/card*; do
  case ${c##*/} in *-*) continue ;; esac
  # The card's device is the PCI function; virtio_gpu drives the virtio device under it.
  case $(readlink -f "$c"/device/virtio*/driver) in */virtio_gpu) card=/dev/dri/${c##*/}; break ;; esac
done
[ -n "$card" ] && export AQ_DRM_DEVICES=$card
# libseat would try fstestvm-seatd first; this session is logind's, on seat0.
export LIBSEAT_BACKEND=logind LIBGL_ALWAYS_SOFTWARE=1 XDG_SESSION_TYPE=wayland XDG_CURRENT_DESKTOP=Hyprland
exec Hyprland --config /etc/fstestvm/hyprland.lua
