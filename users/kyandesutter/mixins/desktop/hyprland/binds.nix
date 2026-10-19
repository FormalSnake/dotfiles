{ pkgs, config, lib, useFormalshell, dmsBin, fsBin, fsIpc, ... }:
let
  # Focused-output-aware brightness keys (dms arm only; the formalshell arm
  # calls the shell's `display brightnessStep`, which picks the device itself).
  #
  # DMS's own `brightness increment/decrement` with an empty device selector
  # resolves to its "preferred device", and its default picks the internal
  # backlight whenever the internal panel is active AT ALL, not whichever
  # output is currently focused. On a docked laptop that means the brightness
  # keys always hit the internal panel, even while focused on the desk monitor.
  # So this script picks the device itself, keyed off Hyprland's *focused*
  # monitor: internal-panel regex match (or hyprctl unreachable) → empty
  # selector (DMS's own internal-panel default), otherwise the first `ddc:`
  # device from `brightness list`.
  #
  # DDC ids are discovered fresh on every keypress rather than hardcoded or
  # pinned once: they're `ddc:i2c-<N>`, and the i2c bus number a monitor lands
  # on shifts across boots/replugs (udev enumeration order, not a stable
  # identity).
  brightnessKey = pkgs.writeShellApplication {
    name = "brightness-key";
    # dms on PATH rather than interpolating dmsBin directly: the dms-shell
    # store path embeds a literal "=" (its +date=... version suffix), which
    # shellcheck's parser misreads as a `word=value` assignment prefix
    # (SC2276) when that path is the leading token of a command.
    runtimeInputs = [
      config.programs.dank-material-shell.package # dms
      pkgs.hyprland # hyprctl
      pkgs.jq
      pkgs.gnugrep
      pkgs.coreutils
    ];
    text = ''
      dir="''${1:?usage: brightness-key up|down}"
      case "$dir" in
        up) verb=increment ;;
        down) verb=decrement ;;
        *) echo "usage: brightness-key up|down" >&2; exit 1 ;;
      esac

      focused="$(hyprctl monitors -j 2>/dev/null | jq -r 'first(.[] | select(.focused)) | .name // empty')"
      device=""
      if [ -n "$focused" ] && ! printf '%s' "$focused" | grep -qiE '^(eDP|LVDS|DSI)'; then
        device="$(dms ipc call brightness list 2>/dev/null | grep -oE 'ddc:[^[:space:]]+' | head -n1 || true)"
      fi
      dms ipc call brightness "$verb" 5 "$device"
    '';
  };

  # Shell-facing binds (launcher, clipboard, theme, lock, screenshots,
  # media/volume/brightness keys) in a per-shell arm picked by
  # kyan.desktop.shell; everything compositor-native is shared below.
  #
  # `locked = true` is Hyprland's allow-when-locked: volume and brightness keep
  # working on the lock screen. `repeating = true` is held-key repeat (the old
  # `bindel`).
  shellBinds =
    if useFormalshell then ''
      -- FormalShell IPC. `menu toggle` is the no-argument verb M13 added for
      -- exactly this bind: root summon when closed, close when already open.
      hl.bind(mod .. " + Space", hl.dsp.exec_cmd("${fsIpc [ "menu" "toggle" ]}"))
      -- Emoji picker (M12): the menu's emoji route, same muscle memory as
      -- DMS's spotlight :e trigger. Enter copies the pick, the clipboard
      -- service captures it.
      hl.bind(mod .. " + period", hl.dsp.exec_cmd("${fsIpc [ "menu" "summon" "emoji" ]}"))
      -- ñ is a dedicated key on the es layout; its XKB keysym is `ntilde`.
      hl.bind(mod .. " + ntilde", hl.dsp.exec_cmd("${fsIpc [ "menu" "summon" "clipboard" ]}"))
      -- Quake console (FormalShell M37): one ghostty that drops over whatever
      -- workspace you are on and parks on Hyprland's special:formalshell-console
      -- when toggled off, session intact. The shell spawns it from
      -- console.command; nothing here needs a window rule, since it places the
      -- window itself on every show. `+` is unshifted on the es layout.
      hl.bind(mod .. " + plus", hl.dsp.exec_cmd("${fsIpc [ "console" "toggle" ]}"))
      hl.bind(mod .. " + SHIFT + T", hl.dsp.exec_cmd("${fsBin} theme mode toggle"))
      -- Sleep: lock then suspend on demand, so resume lands on the lock screen
      -- (exec_cmd runs through sh -c).
      hl.bind(mod .. " + SHIFT + Escape", hl.dsp.exec_cmd("${fsIpc [ "lock" "lock" ]} && systemctl suspend"))

      -- Screenshots via the shell (M12 screenshot IPC target: grim/slurp on the
      -- wrapper PATH, saves to screenshot.directory and wl-copy's the image,
      -- success lands as a shell notification). Owner rule: when the shell has
      -- the feature, prefer it over the compositor's built-in: it's WM-agnostic,
      -- so the binds survive compositor changes. Print = whole screen,
      -- Mod+Shift+S = the capture picker (macOS Cmd+Shift+5): a toolbar of
      -- three shot and three record modes, digits 1-6 to switch between them,
      -- Tab and the arrows to cycle windows, Return to commit. `screenshot
      -- region` is the older bare-slurp route with no toolbar and no
      -- recording at all, so it is deliberately not bound here.
      hl.bind("Print", hl.dsp.exec_cmd("${fsIpc [ "screenshot" "full" "default" ]}"))
      hl.bind(mod .. " + SHIFT + S", hl.dsp.exec_cmd("${fsIpc [ "screenshot" "pick" "smart" "default" ]}"))

      -- Volume via wpctl: FormalShell's AudioService tracks PipeWire directly
      -- and auto-shows the volume OSD on any external change, so the keys don't
      -- need to route through the shell. Brightness does: the shell steps the
      -- focused output (backlight or DDC) through one writer per device and
      -- shows the OSD itself. Media routes through the shell's active MPRIS
      -- player.
      hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("${pkgs.wireplumber}/bin/wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 3%+"), { locked = true, repeating = true })
      hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 3%-"), { locked = true, repeating = true })
      hl.bind("XF86AudioMute", hl.dsp.exec_cmd("${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))
      hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"))
      hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("${fsIpc [ "display" "brightnessStep" "5" ]}"), { locked = true, repeating = true })
      hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("${fsIpc [ "display" "brightnessStep" "-5" ]}"), { locked = true, repeating = true })
      hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("${fsIpc [ "media" "playPause" ]}"))
      hl.bind("XF86AudioPause", hl.dsp.exec_cmd("${fsIpc [ "media" "playPause" ]}"))
      hl.bind("XF86AudioNext", hl.dsp.exec_cmd("${fsIpc [ "media" "next" ]}"))
      hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("${fsIpc [ "media" "previous" ]}"))
    '' else ''
      -- App launcher / clipboard / theme / lock via DMS IPC.
      hl.bind(mod .. " + Space", hl.dsp.exec_cmd("${dmsBin} ipc call spotlight toggle"))
      -- Emoji picker: the emojiLauncher plugin (enabled in mixins/desktop/dms.nix) adds
      -- an emoji/unicode surface to DMS's spotlight under its `:e` trigger,
      -- toggleQuery opens the launcher pre-filled with it.
      hl.bind(mod .. " + period", hl.dsp.exec_cmd("${dmsBin} ipc call spotlight toggleQuery :e"))
      -- ñ is a dedicated key on the es layout; its XKB keysym is `ntilde`.
      hl.bind(mod .. " + ntilde", hl.dsp.exec_cmd("${dmsBin} ipc call clipboard toggle"))
      hl.bind(mod .. " + SHIFT + T", hl.dsp.exec_cmd("${dmsBin} ipc call theme toggle"))
      -- Sleep: lock then suspend on demand, so resume lands on the lock screen.
      hl.bind(mod .. " + SHIFT + Escape", hl.dsp.exec_cmd("${dmsBin} ipc call lock lock && systemctl suspend"))

      -- Screenshots via DMS (owner rule: the shell owns it, so the binds
      -- survive compositor changes). `dms screenshot` is a top-level
      -- subcommand, not `ipc call`. Print = whole screen; Mod+Shift+S = region
      -- picker (macOS Cmd+Shift+4; bare `dms screenshot` defaults to region).
      hl.bind("Print", hl.dsp.exec_cmd("${dmsBin} screenshot full"))
      hl.bind(mod .. " + SHIFT + S", hl.dsp.exec_cmd("${dmsBin} screenshot"))

      -- Volume / brightness / media all route through DMS so they share one OSD
      -- and stay in sync with the shell. Brightness goes via brightness-key (see
      -- the let block), which resolves the device from Hyprland's focused
      -- monitor instead of DMS's internal-panel-first default.
      hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("${dmsBin} ipc call audio increment 3"), { locked = true, repeating = true })
      hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("${dmsBin} ipc call audio decrement 3"), { locked = true, repeating = true })
      hl.bind("XF86AudioMute", hl.dsp.exec_cmd("${dmsBin} ipc call audio mute"))
      hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("${dmsBin} ipc call audio micmute"))
      hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("${brightnessKey}/bin/brightness-key up"), { locked = true, repeating = true })
      hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("${brightnessKey}/bin/brightness-key down"), { locked = true, repeating = true })
      hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("${dmsBin} ipc call mpris playPause"))
      hl.bind("XF86AudioPause", hl.dsp.exec_cmd("${dmsBin} ipc call mpris playPause"))
      hl.bind("XF86AudioNext", hl.dsp.exec_cmd("${dmsBin} ipc call mpris next"))
      hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("${dmsBin} ipc call mpris previous"))
      hl.bind("XF86AudioStop", hl.dsp.exec_cmd("${dmsBin} ipc call mpris stop"))
    '';
in
''
  -- Keybinds (mirror the macOS/aerospace muscle memory, SUPER as mod)
  ${shellBinds}

  hl.bind(mod .. " + Return", hl.dsp.exec_cmd(terminal))
  -- Reclaim the laptop's Copilot key: it launches Claude, not Copilot.
  -- Microsoft's spec (which ASUS honours) has the key emit Meta+Shift+F23;
  -- this drops a fresh local ghostty into `claude`, cwd'd at the nix config.
  hl.bind(mod .. " + SHIFT + F23", hl.dsp.exec_cmd("ghostty --working-directory=${config.home.homeDirectory}/.config/nix -e claude"))
  hl.bind(mod .. " + Q", hl.dsp.window.close())
  hl.bind(mod .. " + SHIFT + F", hl.dsp.window.fullscreen({ action = "toggle", mode = "fullscreen" }))
  hl.bind(mod .. " + V", hl.dsp.window.float({ action = "toggle" }))
  hl.bind(mod .. " + B", hl.dsp.exec_cmd("helium"))

  -- Vim-style focus/move (aerospace alt-hjkl), mapped onto the scrolling
  -- tape's column model: H/L walk columns (layout-aware, so they wrap and
  -- scroll the tape rather than jumping to a neighbouring monitor), J/K walk
  -- windows stacked inside the focused column.
  hl.bind(mod .. " + H", hl.dsp.layout("focus l"))
  hl.bind(mod .. " + L", hl.dsp.layout("focus r"))
  hl.bind(mod .. " + J", hl.dsp.focus({ direction = "d" }))
  hl.bind(mod .. " + K", hl.dsp.focus({ direction = "u" }))
  hl.bind(mod .. " + SHIFT + H", hl.dsp.layout("swapcol l"))
  hl.bind(mod .. " + SHIFT + L", hl.dsp.layout("swapcol r"))
  hl.bind(mod .. " + SHIFT + J", hl.dsp.window.swap({ direction = "d" }))
  hl.bind(mod .. " + SHIFT + K", hl.dsp.window.swap({ direction = "u" }))

  -- Column width. F = full width with gaps (niri's maximize-column), M = true
  -- maximize to the edges, R = cycle the explicit_column_widths presets,
  -- minus/plus = ±10%.
  hl.bind(mod .. " + F", hl.dsp.layout("colresize 1.0"))
  hl.bind(mod .. " + M", hl.dsp.window.fullscreen({ action = "toggle", mode = "maximized" }))
  hl.bind(mod .. " + R", hl.dsp.layout("colresize +conf"))
  hl.bind(mod .. " + minus", hl.dsp.layout("colresize -0.1"))
  hl.bind(mod .. " + plus", hl.dsp.layout("colresize +0.1"))

  -- Tape housekeeping: C scrolls the focused column fully into view; comma
  -- pulls the focused window into the previous column (or expels it back out
  -- if it isn't alone), SHIFT+comma does the same against the next column.
  hl.bind(mod .. " + C", hl.dsp.layout("fit_into_view"))
  hl.bind(mod .. " + comma", hl.dsp.layout("consume_or_expel prev"))
  hl.bind(mod .. " + SHIFT + comma", hl.dsp.layout("consume_or_expel next"))

  -- Workspaces by id, addressed as `code:N` (keycodes, not keysyms) so the
  -- es layout's shifted number row can't break the SHIFT variants.
  for i = 1, 9 do
    hl.bind(mod .. " + code:" .. (i + 9), hl.dsp.focus({ workspace = tostring(i) }))
    hl.bind(mod .. " + SHIFT + code:" .. (i + 9), hl.dsp.window.move({ workspace = tostring(i), follow = true }))
  end

  hl.bind(mod .. " + Tab", hl.dsp.focus({ workspace = "previous" }))

  -- Alt-Tab. Hyprland has no most-recently-used hold-and-cycle switcher
  -- (niri's `recent-windows`). Under FormalShell the shell draws one
  -- (Gala's, under the pantheon preset; the IPC refuses under any other
  -- theme and the keys then do nothing): each press steps the card,
  -- SHIFT reverses, releasing Alt commits. Under DMS this is a plain stack
  -- cycle. Alt+grave (cycle windows of the same app) has no equivalent
  -- and is dropped.
  ${if useFormalshell then ''
  hl.bind("ALT + Tab", hl.dsp.exec_cmd("${fsIpc [ "switcher" "next" ]}"), { repeating = true })
  hl.bind("ALT + SHIFT + Tab", hl.dsp.exec_cmd("${fsIpc [ "switcher" "prev" ]}"), { repeating = true })
  -- `transparent`: Hyprland shadows a bind whose key is still held when
  -- another bind consumes a press (KeybindManager.cpp, shadowKeybinds), so
  -- a plain release bind on Alt never fires after an Alt+Tab; a
  -- transparent one is skipped by the shadowing.
  hl.bind("ALT + Alt_L", hl.dsp.exec_cmd("${fsIpc [ "switcher" "commit" ]}"), { release = true, transparent = true })
  hl.bind("ALT + Alt_R", hl.dsp.exec_cmd("${fsIpc [ "switcher" "commit" ]}"), { release = true, transparent = true })
  '' else ''
  hl.bind("ALT + Tab", hl.dsp.window.cycle_next())
  hl.bind("ALT + SHIFT + Tab", hl.dsp.window.cycle_next({ next = false }))
  ''}
  -- MX Master 3S, usable without the keyboard. Its three thumb buttons are
  -- remapped to keys in modules/nixos/mixins/hardware/mouse.nix: the gesture button is
  -- Mod, so thumb + main wheel walks workspaces, and back/forward arrive as
  -- KEY_F13/KEY_F14 and walk columns. Binds match keysyms, not keycodes, and
  -- the es layout gives those two XF86Tools and XF86Launch5 (it has no F13/F14
  -- keysym at all). Check with
  -- `xkbcli compile-keymap --layout es | rg 'key <FK1[34]>'` before touching
  -- either half.
  hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
  hl.bind(mod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
  hl.bind("XF86Tools", hl.dsp.layout("focus l"))
  hl.bind("XF86Launch5", hl.dsp.layout("focus r"))

  -- Mouse drag/resize (aerospace SUPER+LMB move, SUPER+RMB resize).
  hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
  hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
''
