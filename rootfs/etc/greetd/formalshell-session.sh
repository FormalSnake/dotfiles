#!/bin/sh
# Written by `formalshell install`; `formalshell update` rewrites it.
export XDG_RUNTIME_DIR=/run/formalshell-greeter
export HOME=/var/lib/formalshell-greeter
# pam_env's xdg.conf derives these from the greeter account's passwd home, /var/lib/greetd, so
# the greeter would read its settings.json from there.
unset XDG_CONFIG_HOME XDG_STATE_HOME XDG_CACHE_HOME XDG_DATA_HOME
export XDG_SESSION_TYPE=wayland
printf 'output * bg #000000 solid_color\ninput type:keyboard {\n  xkb_layout es\n  xkb_options caps:escape\n}\n' > "$HOME/sway.conf"
# A compositor killed with greetd leaves its socket; the wait below would take it.
rm -f "$XDG_RUNTIME_DIR"/wayland-*
sway --config "$HOME/sway.conf" &
compositor=$!
for _ in $(seq 100); do
  socket=$(find "$XDG_RUNTIME_DIR" -maxdepth 1 -name 'wayland-*' ! -name '*.lock' -print -quit 2>/dev/null)
  [ -n "$socket" ] && break
  sleep 0.1
done
export WAYLAND_DISPLAY=$(basename "$socket")
/opt/fspec/current/bin/formalshell-greeter
kill "$compositor" 2>/dev/null
wait "$compositor" 2>/dev/null
