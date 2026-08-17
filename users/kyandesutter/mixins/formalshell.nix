{ config, lib, pkgs, inputs, osConfig ? { }, ... }:
let
  # Shell selector from the host (kyan.desktop.shell in
  # modules/nixos/mixins/hyprland.nix, default "dms").
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
      # The system-side unit (modules/nixos/mixins/hyprland.nix lockBeforeSleep)
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
        # Weather sits next to the clock rather than out in the right region:
        # both are ambient facts you read without acting on, and pairing them
        # leaves nowPlaying and visualizer to read as the one media group they
        # are.
        bar.layout.center = [ "clock" "weather" "nowPlaying" "visualizer" ];
        # Two-tier right region. A chevron in the right region governs what
        # PRECEDES it (M25), so the collapsible group leads and the permanent
        # cells sit outboard against the screen edge. That ordering is what
        # keeps the chevron and everything right of it at a fixed x: the
        # reveal grows leftward into empty bar instead of shoving the cells
        # you were looking at.
        #
        # The split is monitor-versus-consult. Charge, volume, connectivity
        # and pending notifications are state you glance at; bluetooth,
        # tailscale, github, usage and the SNI tray are things you go
        # and look at. `indicators` stays permanent because its cells already
        # self-hide, so they cost nothing at rest and matter exactly when they
        # appear (recording, DND, night light, a due reminder). Collapse state
        # is per region in state.json and starts collapsed, so the bar boots
        # at five cells rather than eleven.
        bar.layout.right = [ "bluetooth" "custom:dualsense" "tailscale" "github" "usage" "tray" "chevron" "battery" "audio" "network" "bell" "indicators" ];
        # Codex off: the usage panel polls and renders a section per provider,
        # and this machine only ever signs into Claude, so the CODEX section
        # was permanently reporting on a tool that never gets used.
        usage.codex = false;
        # Controller charge, next to the bluetooth cell it arrives through.
        # Sits in the collapsible tier because it's blank whenever no
        # controller is connected, which is most of the time. Absolute profile
        # path: the shell's own systemd user service has no home profile bin
        # on PATH. 30s beats the 5s default here — the controller reports
        # charge in 10% buckets, so a faster poll can't say anything new.
        bar.modules = [
          {
            id = "dualsense";
            type = "command";
            command = [ "${config.home.profileDirectory}/bin/dualsense-bar" ];
            interval = 30000;
          }
        ];
        # Apple Music animated album covers in the media panel (off upstream).
        media.appleMusicArt = true;
      };
    };

    # DMS goes dormant, not away: mixins/dms.nix stays imported because its
    # generated ~/.config/matugen/config.toml and templates are what
    # FormalShell's ThemeEngine merges into its own matugen run (ghostty,
    # neovim, spicetify, obsidian, btop, yazi, hypr-border all
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
