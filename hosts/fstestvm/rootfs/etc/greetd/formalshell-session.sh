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
# sway draws its pointer over the splash, and the greeter only takes it over once it moves: the
# seat starts on a theme whose every cursor is one transparent pixel, sway hides the still pointer
# at three seconds, and the real theme comes back after that, so the next move shows it.
blank=$HOME/icons/formalos-blank/cursors
if [ ! -e "$blank/default" ]; then
  mkdir -p "$blank"
  echo WGN1chAAAAAAAAEAAQAAAAIA/f8YAAAAHAAAACQAAAACAP3/GAAAAAEAAAABAAAAAQAAAAAAAAAAAAAAAAAAAAAAAAA= | base64 -d > "$blank/default"
  for n in left_ptr arrow top_left_arrow text xterm pointer hand2; do ln -sf default "$blank/$n"; done
fi
export XCURSOR_PATH=$HOME/icons:/usr/share/icons
printf 'output * bg %s\nseat * xcursor_theme formalos-blank 24\nseat * hide_cursor 3000\n' "$bg" > "$HOME/sway.conf"
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
(sleep 3; ipc=$(find "$XDG_RUNTIME_DIR" -maxdepth 1 -name 'sway-ipc.*.sock' -print -quit)
  swaymsg -s "$ipc" 'output * bg #000000 solid_color' >/dev/null 2>&1
  sleep 1
  swaymsg -s "$ipc" 'seat * xcursor_theme default 24' >/dev/null 2>&1) &
wait "$greeter"
grim /tmp/formalshell-greeter-post-auth.png
kill "$compositor" 2>/dev/null
wait "$compositor" 2>/dev/null
