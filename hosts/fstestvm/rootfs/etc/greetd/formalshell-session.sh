#!/bin/sh
# greetd's default_session, as the real hosts run it, on the VM's display: sway in software
# (virtio-gpu has no GL here), the session log dev/smoke-greeter.sh reads, and a grim frame after
# the greeter exits. The keymap stays us, the layout `fspec vm type` types through.
exec >>/tmp/formalshell-greeter-session.log 2>&1
set -x
export XDG_RUNTIME_DIR=/run/formalshell-greeter
export HOME=/var/lib/formalshell-greeter
unset XDG_CONFIG_HOME XDG_STATE_HOME XDG_CACHE_HOME XDG_DATA_HOME
# libseat would try fstestvm-seatd first; this session is logind's, on seat0.
export XDG_SESSION_TYPE=wayland WLR_RENDERER=pixman LIBSEAT_BACKEND=logind
card=
for c in /sys/class/drm/card*; do
  case ${c##*/} in *-*) continue ;; esac
  # The card's device is the PCI function; virtio_gpu drives the virtio device under it.
  case $(readlink -f "$c"/device/virtio*/driver) in */virtio_gpu) card=/dev/dri/${c##*/}; break ;; esac
done
if [ -n "$card" ]; then
  export WLR_DRM_DEVICES=$card
else
  export WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1
fi
rm -f "$XDG_RUNTIME_DIR"/wayland-*
printf 'output * bg #000000 solid_color\n' > "$HOME/sway.conf"
sway --config "$HOME/sway.conf" &
compositor=$!
for _ in $(seq 100); do
  socket=$(find "$XDG_RUNTIME_DIR" -maxdepth 1 -name 'wayland-*' ! -name '*.lock' -print -quit 2>/dev/null)
  [ -n "$socket" ] && break
  sleep 0.1
done
export WAYLAND_DISPLAY=$(basename "$socket")
/opt/fspec/current/bin/formalshell-greeter
grim /tmp/formalshell-greeter-post-auth.png
kill "$compositor" 2>/dev/null
wait "$compositor" 2>/dev/null
