#!/bin/sh
# What the greeter starts on a login: Hyprland on the VM's display, in software, running the shell,
# started the way the real hosts' session entry starts it (uwsm, start-hyprland), so its output
# goes to the journal and not onto the VT. vkms is the smoke rig's card.
card=
for c in /sys/class/drm/card*; do
  case ${c##*/} in *-*) continue ;; esac
  # The card's device is the PCI function; virtio_gpu drives the virtio device under it.
  case $(readlink -f "$c"/device/virtio*/driver) in */virtio_gpu) card=/dev/dri/${c##*/}; break ;; esac
done
[ -n "$card" ] && export AQ_DRM_DEVICES=$card
# libseat would try fstestvm-seatd first; this session is logind's, on seat0.
export LIBSEAT_BACKEND=logind LIBGL_ALWAYS_SOFTWARE=1 XDG_SESSION_TYPE=wayland
exec uwsm start -e -D Hyprland -- hyprland.desktop -- --config /etc/fstestvm/hyprland.lua
