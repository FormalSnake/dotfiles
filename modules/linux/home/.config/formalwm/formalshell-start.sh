# formalwm runs this once its socket is up: the start line `formalshell install` writes, after
# `uwsm finalize`, which puts SHOJIWM_SOCKET on the list uwsm unsets at logout. The user manager
# outlives the session, and a Hyprland login after it would otherwise hand the shell this one's
# socket. NOTIFY_SOCKET is uwsm's unit; a bare `formalwm --tty` has none.
[ -n "$NOTIFY_SOCKET" ] && uwsm finalize SHOJIWM_SOCKET
systemctl --user unset-environment HYPRLAND_INSTANCE_SIGNATURE SHOJIWM_SOCKET && systemctl --user import-environment WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE SHOJIWM_SOCKET XDG_CURRENT_DESKTOP XDG_SESSION_TYPE && systemctl --user start formalshell.service formalshell-watchdog.timer
