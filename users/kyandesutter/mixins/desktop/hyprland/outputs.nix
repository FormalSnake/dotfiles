{ lib, hasNvidia, panel, wsLua, iconThemeName, ... }:
let
  # Monitors
  #
  # g815: both outputs hang off the dGPU. The desk monitor (ASUS PA278CGV,
  # 1440p144) has a 60Hz EDID-preferred timing, so the 144Hz mode is pinned
  # explicitly. Placed at the ORIGIN (0x0) so it is the *primary* display:
  # fullscreen games with no monitor selector target the monitor at (0,0) and
  # enumerate only its modes. vrr = 3 on both outputs: adaptive sync only
  # while a fullscreen game or video asks for it. Always-on VRR (vrr = 1)
  # makes both panels flicker on an idle desktop, brightness tracking the
  # refresh rate as it sinks to the VRR floor: the desk monitor in June 2026,
  # the internal BOE panel in September 2026. The internal 18" WQXGA 240Hz
  # panel sits to its RIGHT at x = 2560, scale 1.25.
  #
  # Everywhere else: the internal panel at its preferred mode, native 1x (the
  # e1504g's 15.6" 1080p panel would otherwise land on a fractional scale).
  monitors =
    if hasNvidia then ''
      -- vrr = 1 on HDMI-A-1 comes up black at boot: the link trains, EDID and
      -- ELD read fine, the CRTC goes active at 144, and no picture ever lands.
      -- 3 holds VRR off until a fullscreen game or video asks for it.
      hl.monitor({ output = "HDMI-A-1", mode = "2560x1440@144", position = "0x0", scale = 1.0, vrr = 3 })
      hl.monitor({ output = "${panel}", mode = "2560x1600@240", position = "2560x0", scale = 1.25, vrr = 3 })
    '' else ''
      hl.monitor({ output = "${panel}", mode = "preferred", position = "auto", scale = 1.0 })
    '';

  # Workspace → monitor binding. On the two-monitor g815, communication (4) and
  # media (8) live on the internal panel and the other seven on the desk
  # monitor; each monitor gets one `default` workspace shown when it comes up
  # (1 on HDMI-A-1, 4 on the panel). When HDMI-A-1 is absent Hyprland relocates
  # its workspaces to the panel and moves them back on reconnect. Single-panel hosts
  # take the names and nothing else.
  workspaceRules =
    if hasNvidia then ''
      local internalWorkspaces = { [4] = true, [8] = true }
      for i = 1, 9 do
        hl.workspace_rule({
          workspace = tostring(i),
          default_name = wsName[i],
          monitor = internalWorkspaces[i] and "${panel}" or "HDMI-A-1",
          default = (i == 1 or i == 4),
        })
      end
    '' else ''
      for i = 1, 9 do
        hl.workspace_rule({ workspace = tostring(i), default_name = wsName[i] })
      end
    '';
in
''
  -- Monitors
  ${monitors}
  -- Catch-all: any other external display at its highest refresh rate
  -- ("highrr" forces the panel's max, unlike "preferred" which is usually
  -- 60Hz), placed to the right of whatever precedes it.
  hl.monitor({ output = "", mode = "highrr", position = "auto", scale = 1.0 })

  -- Variables
  local mod = "SUPER"        -- primary modifier (the physical Cmd-position key)
  local terminal = "ghostty"

  -- Workspaces
  -- Nine named workspaces mirroring the macOS/aerospace assignment. The name
  -- is what the bar renders on each pill, binds and window rules address the
  -- numeric id.
  local wsName = { ${wsLua} }

  ${workspaceRules}

  -- Environment
  -- Cursor theme/size for XWayland (X11) clients: without XCURSOR_THEME they
  -- fall back to a default theme and show a *different* cursor than native
  -- Wayland apps (which read it from home.pointerCursor in session.nix).
  hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
  hl.env("XCURSOR_SIZE", "24")
  -- Qt platform theme (qt6ct) so Qt apps follow the shell's palette (see the
  -- qt6ct notes in mixins/desktop/qt.nix); QS_ICON_THEME is the Quickshell-specific
  -- icon override kept for Qt tooling. Also exported from uwsm/env in session.nix, so
  -- systemd user services (which do NOT inherit Hyprland's environment) get
  -- them too.
  hl.env("QS_ICON_THEME", "${iconThemeName}")
  hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
  ${lib.optionalString hasNvidia ''
  -- NVIDIA + Wayland (explicit-sync is automatic on recent drivers). The
  -- VA-API / GLX vendor picks are also exported from uwsm/env-hyprland in session.nix
  -- so user services get them too.
  hl.env("__GL_GSYNC_ALLOWED", "1")
  hl.env("LIBVA_DRIVER_NAME", "nvidia")
  hl.env("NVD_BACKEND", "direct")
  hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")''}
''
