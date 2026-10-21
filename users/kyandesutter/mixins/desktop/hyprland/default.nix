{ pkgs, config, lib, osConfig, ... }:
let
  flexoki = import ../../flexoki/palette.nix;

  dmsBin = "${config.programs.dank-material-shell.package}/bin/dms";

  # Shell selector from the host (kyan.desktop.shell, default "formalshell") picks
  # which shell the shell-facing binds (binds.nix) spawn into. Both package
  # references stay lazy: only the active arm's option is ever forced, so the
  # inactive shell's package option can be unset without breaking eval.
  useFormalshell = osConfig.kyan.desktop.shell == "formalshell";
  shellColors = if useFormalshell then "formalshell-colors.css" else "dank-colors.css";
  fsBin = "${config.programs.formalshell.package}/bin/formalshell";
  fsIpc = args: "${fsBin} ipc --any-display call " + lib.concatStringsSep " " args;
  # Window rounding follows the shell's own corner radius (settings.json
  # theme.radius, 10 by default), so windows and shell cards share one curve.
  fsRadius = toString ((config.programs.formalshell.settings.theme or { }).radius or 10);

  iconThemeName = "Colloid-Dark";

  # NVIDIA dGPU flag from the host (same gate as dms.nix/godot.nix). The g815
  # specifics in this module (the AQ_DRM_DEVICES pick, the nvidia env, the two-monitor
  # layout) are gated on it, so iGPU-only hosts (e1504g) get a plain Hyprland
  # session with none of the hardcoded g815 PCI paths / modes.
  hasNvidia = (osConfig.kyan or { }).nvidia.enable or false;

  # Internal panel selector. On the g815 the MUX (systems/g815/default.nix)
  # decides which driver owns it, and the connector name changes with the
  # driver (eDP-1 under i915, eDP-2 under nvidia-drm), so match its EDID
  # description instead. Both hl.monitor and hl.workspace_rule take `desc:`.
  panel = if hasNvidia then "desc:BOE NE180QDM-NZC" else "eDP-1";

  # Per-window translucency. Anything under 1.0 makes Hyprland run the blur
  # pass behind every window on every damaged frame. Fine on the RTX 5070;
  # on the e1504g's 32-EU UHD it is the largest steady GPU cost of the
  # session, so windows go opaque there and blur stays for the shell layers
  # (bar, panel, menu, notifications) only.
  windowOpacity = if hasNvidia then "0.96" else "1.0";

  # Workspace pill labels: role → Nerd Font glyph + short name, mirroring the
  # macOS aerospace workspace names (see mixins/macos/aerospace.nix). Rendered into
  # each workspace's `default_name`, which is what Hyprland reports over IPC as
  # `name` and what FormalShell's HyprlandBackend puts on the bar pills
  # (shell/Compositor/hyprland/HyprlandBackend.qml maps `w.name` straight
  # through).
  # Glyph and name are joined by an EM SPACE ( ), not an ASCII space:
  # the bar widget collapses ASCII/nbsp whitespace in the label but preserves
  # it. Written as JSON \u escapes so the private-use glyphs survive editing,
  # glyphs verified present in GeistMono Nerd Font 3.4.0.
  wsName = builtins.fromJSON ''
    {"1": " web", "2": " term", "3": " dev", "4": " chat", "5": " prod", "6": " print", "7": "󰚩 ai", "8": " media", "9": " game"}
  '';
  wsLua = lib.concatMapStringsSep ", " (i: ''"${wsName.${toString i}}"'') (lib.range 1 9);

  args = {
    inherit pkgs config lib flexoki dmsBin useFormalshell fsBin fsIpc fsRadius;
    inherit iconThemeName hasNvidia panel windowOpacity wsLua;
  };
in
{
  imports = [ ./session.nix ];

  # Hyprland is enabled at the system level (programs.hyprland in
  # modules/nixos/mixins/desktop/hyprland.nix), this module owns the user config.
  #
  # Hyprland 0.55 replaced the hyprlang `.conf` config with Lua at
  # ~/.config/hypr/hyprland.lua (the old syntax was removed, not deprecated).
  # home-manager's `wayland.windowManager.hyprland.settings` still serialises
  # hyprlang ($mod = SUPER, bind = …), which the Lua parser rejects
  # ("<name> expected near '$'"), so we write the file ourselves and skip the
  # HM module rather than have it emit a conflicting one.
  #
  # Nix `''` strings are safe here because the Lua contains no literal `${…}`:
  # every `${…}` in the section files is a deliberate Nix interpolation of a store path.
  # API reference: https://wiki.hypr.land/Configuring/ (hl.config, hl.monitor,
  # hl.env, hl.bind, hl.dsp.*, hl.window_rule, hl.layer_rule, hl.workspace_rule,
  # hl.gesture).
  xdg.configFile."hypr/hyprland.lua".text = lib.concatMapStringsSep "\n" (f: import f args) [
    ./chrome.nix
    ./outputs.nix
    ./options.nix
    ./binds.nix
    ./rules.nix
  ];
}
