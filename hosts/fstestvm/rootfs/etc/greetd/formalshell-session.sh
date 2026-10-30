#!/bin/sh
# greetd's default_session, as the real hosts run it, on the VM's display: sway in software
# (the VGA card has no GL), the session log dev/smoke-greeter.sh reads, and a grim frame after
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
  # vkms is the smoke rig's card; the other one is the VM's display.
  case $(readlink -f "$c"/device) in */vkms*) continue ;; esac
  card=/dev/dri/${c##*/}
  break
done
if [ -n "$card" ]; then
  export WLR_DRM_DEVICES=$card
else
  export WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1
fi
rm -f "$XDG_RUNTIME_DIR"/wayland-*
# The first greeter since boot repeats the splash's finished frame, which plymouth leaves on the
# display: the greeter then fades in over the same picture. The scale is the splash script's own.
# sway draws its pointer before the greeter can hide it; it goes after three still seconds.
bg='#000000 solid_color'
if [ ! -e "$XDG_RUNTIME_DIR/booted" ] && [ -n "$card" ]; then
  touch "$XDG_RUNTIME_DIR/booted"
  for c in /sys/class/drm/${card##*/}-*; do
    [ "$(cat "$c/status" 2>/dev/null)" = connected ] || continue
    h=$(head -n 1 "$c/modes"); h=${h#*x}; s=$((h / 500))
    [ "$s" -lt 1 ] && s=1; [ "$s" -gt 4 ] && s=4
    splash=/usr/share/plymouth/themes/formalos/greeter-$s.png
    [ -f "$splash" ] && bg="$splash center #000000"
    break
  done
fi
printf 'output * bg %s\nseat * hide_cursor 3000\n' "$bg" > "$HOME/sway.conf"
sway --config "$HOME/sway.conf" &
compositor=$!
for _ in $(seq 100); do
  socket=$(find "$XDG_RUNTIME_DIR" -maxdepth 1 -name 'wayland-*' ! -name '*.lock' -print -quit 2>/dev/null)
  [ -n "$socket" ] && break
  sleep 0.1
done
export WAYLAND_DISPLAY=$(basename "$socket")
/opt/fspec/current/bin/formalshell-greeter &
greeter=$!
# Once the greeter covers it, the splash under it goes black, so the moment between the greeter's
# exit and sway's is black too.
(sleep 3; swaymsg -s "$(find "$XDG_RUNTIME_DIR" -maxdepth 1 -name 'sway-ipc.*.sock' -print -quit)" 'output * bg #000000 solid_color' >/dev/null 2>&1) &
wait "$greeter"
grim /tmp/formalshell-greeter-post-auth.png
kill "$compositor" 2>/dev/null
wait "$compositor" 2>/dev/null
