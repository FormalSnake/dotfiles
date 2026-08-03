{ config, lib, pkgs, inputs, osConfig ? { }, ... }:
let
  # Shell selector from the host (kyan.desktop.shell in
  # modules/nixos/mixins/niri.nix, default "dms").
  useFormalshell = (((osConfig.kyan or { }).desktop or { }).shell or "dms") == "formalshell";

  fsPkg = inputs.formalshell.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  # Imported unconditionally so programs.formalshell is declared on every
  # Linux host; everything below is inert while the host's shell is dms.
  imports = [ inputs.formalshell.homeModules.default ];

  config = lib.mkIf useFormalshell {
    programs.formalshell = {
      enable = true;
      package = fsPkg;
      # The system-side unit (modules/nixos/mixins/niri.nix lockBeforeSleep)
      # owns lock-on-suspend; the hm module's own user unit would hang off a
      # user-manager sleep.target that never fires under our setup.
      systemd.lockBeforeSleep = false;
      settings = {
        # Syncthing-synced wallpaper folder (modules/nixos/mixins/syncthing.nix)
        # for the picker's wallpaper mode.
        picker.directory = "${config.home.homeDirectory}/Pictures/Wallpapers";
        # Today's default right region plus the opt-in github (M12) and
        # AI-usage (M14) widgets: gh comes from mixins/gh.nix, usage reads
        # ~/.claude/.credentials.json and the codex CLI; all three degrade
        # honestly without auth. Left/center regions absent on purpose, they
        # fall back to defaults (which include the M13b bell).
        bar.layout.right = [ "battery" "audio" "network" "bluetooth" "weather" "github" "usage" "bell" "tray" "indicators" ];
      };
    };

    # DMS goes dormant, not away: mixins/dms.nix stays imported because its
    # generated ~/.config/matugen/config.toml and templates are what
    # FormalShell's ThemeEngine merges into its own matugen run (ghostty,
    # neovim, spicetify, obsidian, btop, yazi, niri-border, wallpaper-path all
    # keep re-theming), and rollback is one kyan.desktop.shell flip. Only the
    # running daemons yield the session. dcal serves nothing here: FormalShell
    # reads local .ics dirs only, it cannot consume dankcal's IPC.
    programs.dank-material-shell.systemd.enable = lib.mkForce false;
    programs.dank-calendar.systemd.enable = lib.mkForce false;

    # helium waits for the session notification daemon (see autostart.nix);
    # with dms.service gone that is formalshell.service.
    systemd.user.services.helium.Unit = {
      After = lib.mkForce [ "formalshell.service" "graphical-session.target" ];
      Wants = lib.mkForce [ "formalshell.service" ];
    };
  };
}
