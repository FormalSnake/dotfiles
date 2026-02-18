#!/usr/bin/env bash
# Toggle hyprsunset nightlight (4000K warm filter)

if pgrep -x hyprsunset >/dev/null; then
    pkill hyprsunset
    notify-send "Nightlight off"
else
    hyprsunset -t 4000 &
    notify-send "Nightlight on" "4000K warm filter"
fi
