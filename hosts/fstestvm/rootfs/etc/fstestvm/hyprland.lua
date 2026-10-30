hl.monitor({ output = "", mode = "preferred", position = "0x0", scale = 1 })
hl.config({
  -- A restarted shell takes back the lock its predecessor held, the locked login's included.
  misc = { disable_watchdog_warning = true, disable_hyprland_logo = true, force_default_wallpaper = 0, background_color = "rgb(000000)", allow_session_lock_restore = true },
})
-- FormalShell's include does the same (docs/examples/hyprland/formalshell.lua).
-- The pointer stays hidden until the shell has faded the desktop in. Hidden
-- twice over: Hyprland draws it for its first frames whatever
-- `cursor.invisible` says, so its cursor manager starts on a theme of
-- transparent cursors too. That reads XCURSOR_THEME once at start, so the
-- variable goes back to the real theme for everything started after it. The
-- shell then writes its marker for this instance and calls
-- formalshell_arrived, which puts the real theme on the pointer and shows it,
-- so a reload after that (the shell's own after each publish) leaves it
-- shown. A shell that never starts gets it back ten seconds in, marker and all.
local blank = "formalos-blank"
local function real_cursor_theme()
  local theme = os.getenv("XCURSOR_THEME") or "default"
  if theme == blank then
    theme = os.getenv("FORMALSHELL_XCURSOR_THEME") or "default"
  end
  return theme
end
function formalshell_arrived()
  local theme = real_cursor_theme()
  hl.env("XCURSOR_THEME", theme)
  hl.exec_cmd("hyprctl setcursor " .. theme .. " " .. (os.getenv("XCURSOR_SIZE") or "24"))
  hl.config({ cursor = { invisible = false } })
end
local arrived = (os.getenv("XDG_RUNTIME_DIR") or "") .. "/formalshell/arrived-" .. (os.getenv("HYPRLAND_INSTANCE_SIGNATURE") or "")
local marker = io.open(arrived, "r")
local arriving = not marker
if marker then
  marker:close()
end
-- Called again after any later file that sets XCURSOR_THEME itself (the
-- installer's entry does, after hypr-user.lua). Only before the start: a
-- reload after it would hand the blank theme to whatever starts next.
function formalshell_blank_cursor()
  if arriving and not os.getenv("FORMALSHELL_CURSOR_STARTED") then
    hl.env("FORMALSHELL_XCURSOR_THEME", real_cursor_theme())
    hl.env("XCURSOR_THEME", blank)
  end
end
if arriving then
  -- One transparent pixel, as an Xcursor file, under every name Hyprland asks for at start.
  local dir = (os.getenv("HOME") or "") .. "/.local/share/icons/" .. blank .. "/cursors/"
  os.execute("mkdir -p '" .. dir .. "'")
  for _, name in ipairs({ "default", "left_ptr", "arrow", "top_left_arrow", "wait", "watch", "progress", "left_ptr_watch", "text", "xterm", "pointer", "hand2" }) do
    local f = io.open(dir .. name, "wb")
    if f then
      f:write("Xcur\16\0\0\0\0\0\1\0\1\0\0\0\2\0\253\255\24\0\0\0\28\0\0\0$\0\0\0\2\0\253\255\24\0\0\0\1\0\0\0\1\0\0\0\1\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0")
      f:close()
    end
  end
  formalshell_blank_cursor()
  hl.config({ cursor = { invisible = true } })
  hl.on("hyprland.start", function()
    hl.env("FORMALSHELL_CURSOR_STARTED", "1")
    hl.env("XCURSOR_THEME", real_cursor_theme())
  end)
end
hl.on("hyprland.start", function()
  hl.exec_cmd([==[sleep 10 && mkdir -p "$XDG_RUNTIME_DIR/formalshell" && touch "$XDG_RUNTIME_DIR/formalshell/arrived-$HYPRLAND_INSTANCE_SIGNATURE" && hyprctl eval 'formalshell_arrived()']==])
end)
hl.layer_rule({ name = "formalshell-veil", match = { namespace = "formalshell:veil" }, no_anim = true })
hl.on("hyprland.start", function() hl.exec_cmd([==[systemctl --user import-environment WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP XDG_SESSION_TYPE && systemctl --user start formalshell.service]==]) end)
hl.bind("SUPER + Return", hl.dsp.exec_cmd("foot"))
hl.bind("SUPER + Space", hl.dsp.exec_cmd([==[/opt/fspec/current/bin/formalshell ipc --any-display call menu toggle]==]))
hl.bind("SUPER + SHIFT + E", hl.dsp.exec_cmd([==[/opt/fspec/current/bin/formalshell ipc --any-display call power logout]==]))
