hl.monitor({ output = "", mode = "preferred", position = "0x0", scale = 1 })
hl.config({
  misc = { disable_watchdog_warning = true, disable_hyprland_logo = true, force_default_wallpaper = 0 },
})
hl.on("hyprland.start", function() hl.exec_cmd([==[/opt/fspec/current/bin/formalshell]==]) end)
hl.bind("SUPER + Return", hl.dsp.exec_cmd("foot"))
hl.bind("SUPER + Space", hl.dsp.exec_cmd([==[/opt/fspec/current/bin/formalshell ipc --any-display call menu toggle]==]))
hl.bind("SUPER + SHIFT + E", hl.dsp.exit())
