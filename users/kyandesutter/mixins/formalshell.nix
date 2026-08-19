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
    # notify-send, for testing and scripting against the shell's own
    # notification daemon (2026-08-19: neither host had it installed, which
    # read as "toasts are broken" when they were merely never fired).
    home.packages = [ pkgs.libnotify ];

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
        bar.layout.center = [ "clock" "nowPlaying" "visualizer" ];
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
        # appear (recording, DND, night light, a due reminder). airpods and
        # dualsense (M29 builtins) self-hide the same way, so airpods earns
        # the permanent tier next to audio (owner ask 2026-08-18) and
        # dualsense keeps its old collapsible slot. Collapse state is per
        # region in state.json and starts collapsed, so the bar boots at
        # five cells rather than eleven.
        # Weather rides the permanent tier (owner ask 2026-08-18, out of the
        # center group), leading it so the battery/audio/network cluster
        # stays contiguous against the screen edge.
        bar.layout.right = [ "display" "bluetooth" "dualsense" "tailscale" "github" "usage" "tray" "chevron" "weather" "battery" "airpods" "audio" "network" "bell" "indicators" ];
        # Codex off: the usage panel polls and renders a section per provider,
        # and this machine only ever signs into Claude, so the CODEX section
        # was permanently reporting on a tool that never gets used.
        usage.codex = false;
        # Apple Music animated album covers in the media panel (off upstream).
        media.appleMusicArt = true;
        # Toast corner (M34). Matches the shipped default on purpose: the
        # choice is the owner's, so it is written down rather than inherited.
        notifications.position = "bottom-right";
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

    # Everything launched from the shell's menu lands in formalshell.service's
    # cgroup: quickshell's DesktopEntry.execute only double-forks, it never
    # moves the child into a scope of its own. With the default
    # KillMode=control-group that means every rebuild restart takes the
    # launched apps down with the shell, kopuz mid-track included. Killing
    # only the main process leaves them running. Quickshell's own Process
    # children (the wl-paste watchers, cava) still go, since it kills managed
    # processes when it exits, and detached apps are exactly the set that
    # should survive a shell restart.
    systemd.user.services.formalshell.Service.KillMode = "process";

    # helium waits for the session notification daemon (see autostart.nix);
    # with dms.service gone that is formalshell.service.
    systemd.user.services.helium.Unit = {
      After = lib.mkForce [ "formalshell.service" "graphical-session.target" ];
      Wants = lib.mkForce [ "formalshell.service" ];
    };
  };
}
