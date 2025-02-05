#!/bin/sh

SSID=$(ipconfig getsummary en0 | awk -F ' SSID : '  '/ SSID : / {print $2}')

sketchybar --set "$NAME" label="W ⋮ $SSID"
