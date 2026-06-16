{ pkgs, ... }:
{
  # Hyprland is enabled at the system level (programs.hyprland in
  # modules/nixos/mixins/hyprland.nix); here we only manage the user config.
  #
  # Hyprland 0.55 dropped the hyprlang (INI-style) `hyprland.conf` in favour of
  # a Lua config at ~/.config/hypr/hyprland.lua (the old syntax is removed, not
  # just deprecated). home-manager's `wayland.windowManager.hyprland.settings`
  # still serialises the old hyprlang syntax ($mod = SUPER, bind = …), which a
  # Lua parser rejects ("<name> expected near '$'"). Until home-manager grows a
  # Lua generator we write hyprland.lua ourselves and skip the HM module so it
  # doesn't emit a conflicting/ignored file.
  #
  # API reference: https://wiki.hypr.land/Configuring/  (Lua: hl.config,
  # hl.monitor, hl.env, hl.bind, hl.dsp.*, hl.window_rule, hl.on).
  xdg.configFile."hypr/hyprland.lua".text = ''
    -- — Monitors —
    -- Internal 18" WQXGA 240Hz panel. Adjust scale to taste (1.0–1.5).
    hl.monitor({ output = "eDP-1", mode = "2560x1600@240", position = "0x0", scale = 1.25 })
    -- Catch-all: any external display at its native res, placed to the right.
    hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1.0 })

    -- — Variables —
    local mod = "SUPER"        -- primary modifier (the physical Cmd-position key)
    local terminal = "ghostty"

    -- — Environment —
    hl.env("XCURSOR_SIZE", "24")
    -- NVIDIA + Wayland hints (explicit-sync is automatic on recent drivers).
    hl.env("__GL_GSYNC_ALLOWED", "1")

    -- — Autostart (replaces exec-once) —
    -- caelestia shell auto-starts via its systemd user service. A polkit agent
    -- is needed for GUI auth prompts.
    hl.on("hyprland.start", function()
      hl.exec_cmd("systemctl --user start hyprpolkitagent")
      hl.exec_cmd("wl-paste --watch cliphist store")
    end)

    -- — General options —
    hl.config({
      input = {
        kb_layout = "es",
        follow_mouse = 1,
        sensitivity = 0,
        touchpad = { natural_scroll = true },
      },
      general = {
        gaps_in = 4,
        gaps_out = 8,
        border_size = 2,
        layout = "dwindle",
        resize_on_border = true,
      },
      decoration = {
        rounding = 10,
        blur = { enabled = true, size = 6, passes = 3 },
      },
      animations = { enabled = true },
      misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
      },
    })

    -- — Keybinds (mirror the macOS/aerospace muscle memory, SUPER as mod) —
    -- App launcher (caelestia registers this Hyprland global shortcut).
    hl.bind(mod .. " + Space", hl.dsp.global("caelestia:launcher"))

    hl.bind(mod .. " + Return", hl.dsp.exec_cmd(terminal))
    hl.bind(mod .. " + Q", hl.dsp.window.close())
    hl.bind(mod .. " + SHIFT + F", hl.dsp.window.fullscreen({ action = "toggle", mode = "fullscreen" }))
    hl.bind(mod .. " + V", hl.dsp.window.float({ action = "toggle" }))
    hl.bind(mod .. " + B", hl.dsp.exec_cmd("helium"))

    -- Vim-style focus (aerospace alt-hjkl → SUPER+hjkl).
    hl.bind(mod .. " + H", hl.dsp.focus({ direction = "l" }))
    hl.bind(mod .. " + J", hl.dsp.focus({ direction = "d" }))
    hl.bind(mod .. " + K", hl.dsp.focus({ direction = "u" }))
    hl.bind(mod .. " + L", hl.dsp.focus({ direction = "r" }))

    -- Vim-style move (aerospace alt-shift-hjkl → SUPER+SHIFT+hjkl).
    hl.bind(mod .. " + SHIFT + H", hl.dsp.window.move({ direction = "l" }))
    hl.bind(mod .. " + SHIFT + J", hl.dsp.window.move({ direction = "d" }))
    hl.bind(mod .. " + SHIFT + K", hl.dsp.window.move({ direction = "u" }))
    hl.bind(mod .. " + SHIFT + L", hl.dsp.window.move({ direction = "r" }))

    -- Named workspaces (1=web 2=terminal 3=development 4=communication
    -- 5=productivity 6=print 7=ai 8=media 9=gaming) — matches aerospace.
    for i = 1, 9 do
      hl.bind(mod .. " + " .. i, hl.dsp.focus({ workspace = i }))
      hl.bind(mod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = tostring(i), follow = true }))
    end

    hl.bind(mod .. " + Tab", hl.dsp.focus({ workspace = "previous" }))

    -- Screenshots (grim/slurp; caelestia also ships its own if preferred).
    hl.bind("Print", hl.dsp.exec_cmd("grim - | wl-copy"))
    hl.bind(mod .. " + SHIFT + S", hl.dsp.exec_cmd('grim -g "$(slurp)" - | wl-copy'))

    -- Volume / brightness (repeat while held).
    hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"), { repeating = true })
    hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { repeating = true })
    hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))
    hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set 5%+"), { repeating = true })
    hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"), { repeating = true })

    -- Mouse drag/resize (aerospace SUPER+LMB move, SUPER+RMB resize).
    hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
    hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

    -- — Window → workspace rules (ported from the aerospace setup; Linux app
    --   classes. Verify exact classes on hardware with `hyprctl clients`). —
    hl.window_rule({ match = { class = "^([Hh]elium)$" }, workspace = "1 silent" })                       -- web
    hl.window_rule({ match = { class = "^(com.mitchellh.ghostty)$" }, workspace = "2 silent" })           -- terminal
    hl.window_rule({ match = { class = "^([Cc]ode|[Zz]ed|dev.zed.Zed)$" }, workspace = "3 silent" })      -- development
    hl.window_rule({ match = { class = "^([Ss]lack|WhatsApp)$" }, workspace = "4 silent" })               -- communication
    hl.window_rule({ match = { class = "^([Cc]laude)$" }, workspace = "7 silent" })                       -- ai
    hl.window_rule({ match = { class = "^([Ss]potify)$" }, workspace = "8 silent" })                      -- media
    hl.window_rule({ match = { class = "^([Ss]team|steam|vesktop|discord)$" }, workspace = "9 silent" })  -- gaming
    hl.window_rule({ match = { title = "^(Picture-in-Picture)$" }, float = true })                        -- floating PiP
  '';

  # Clipboard history for the SUPER-launcher / cliphist.
  home.packages = with pkgs; [
    cliphist
    hyprpolkitagent
  ];
}
