hl.monitor({ output = "", mode = "preferred", position = "0x0", scale = 1 })
hl.config({
  misc = { disable_watchdog_warning = true, disable_hyprland_logo = true, force_default_wallpaper = 0, background_color = "rgb(000000)" },
})
-- FormalShell's include does the same (docs/examples/hyprland/formalshell.lua): the pointer hidden
-- until the shell has faded the desktop in, the veil left to fade itself.
local arrived = (os.getenv("XDG_RUNTIME_DIR") or "") .. "/formalshell/arrived-" .. (os.getenv("HYPRLAND_INSTANCE_SIGNATURE") or "")
local marker = io.open(arrived, "r")
if marker then marker:close() else hl.config({ cursor = { invisible = true } }) end
hl.on("hyprland.start", function()
  hl.exec_cmd([==[sleep 10 && mkdir -p "$XDG_RUNTIME_DIR/formalshell" && touch "$XDG_RUNTIME_DIR/formalshell/arrived-$HYPRLAND_INSTANCE_SIGNATURE" && hyprctl eval 'hl.config({ cursor = { invisible = false } })']==])
end)
hl.layer_rule({ name = "formalshell-veil", match = { namespace = "formalshell:veil" }, no_anim = true })
hl.on("hyprland.start", function() hl.exec_cmd([==[/opt/fspec/current/bin/formalshell]==]) end)
hl.bind("SUPER + Return", hl.dsp.exec_cmd("foot"))
hl.bind("SUPER + Space", hl.dsp.exec_cmd([==[/opt/fspec/current/bin/formalshell ipc --any-display call menu toggle]==]))
hl.bind("SUPER + SHIFT + E", hl.dsp.exec_cmd([==[/opt/fspec/current/bin/formalshell ipc --any-display call power logout]==]))
