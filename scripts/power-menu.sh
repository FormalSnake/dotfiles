#!/usr/bin/env bash
# Power menu using walker --dmenu

CHOICE=$(printf "Lock\nSuspend\nLogout\nReboot\nShutdown" | walker --dmenu)

case "$CHOICE" in
    Lock)
        ~/.config/formalconf/scripts/lock-screen.sh
        ;;
    Suspend)
        systemctl suspend
        ;;
    Logout)
        hyprctl dispatch exit
        ;;
    Reboot)
        systemctl reboot
        ;;
    Shutdown)
        systemctl poweroff
        ;;
esac
