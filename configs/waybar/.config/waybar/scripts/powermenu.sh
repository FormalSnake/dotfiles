#!/bin/bash

options="󰐥 Power Off\n󰜉 Restart\n󰤄 Suspend"

selected=$(echo -e "$options" | wofi --dmenu --prompt "Power Menu" --width 200 --height 150)

case "$selected" in
    "󰐥 Power Off") systemctl poweroff ;;
    "󰜉 Restart") systemctl reboot ;;
    "󰤄 Suspend") systemctl suspend ;;
esac
