{ pkgs, config, ... }:
{
  # Browse the macbook's home over SSHFS at ~/macbook — a real filesystem path, so
  # it shows up as a folder in Files/Nautilus AND works with rg, nvim, etc. Reuses
  # the `macbook` SSH host (mixins/ssh.nix → Tailscale + 1Password agent); no
  # dedicated key. g815-only (imported via linux.nix); irrelevant on the Mac itself.

  home.packages = [ pkgs.sshfs ];

  # The real mountpoint is hidden on purpose. glib's
  # g_unix_mount_guess_should_display() treats every mount under $HOME as a
  # user-visible volume, so gvfs's udisks2 volume monitor adopts the sshfs mount and
  # sniffs its x-content type by walking the mount root. Over SSH that walk (300+
  # entries at 100 to 400 ms per stat) never finishes, so the monitor never takes
  # org.gtk.vfs.UDisks2VolumeMonitor, its systemd unit times out after 90s, and every
  # GIO client that builds a GVolumeMonitor (Nautilus at startup, every GTK file
  # chooser) burns the 25s D-Bus timeout waiting for the name. Measured on e1504g:
  # 30s to open a Nautilus window with the mount at ~/macbook, 50 ms with it hidden.
  # A "/." anywhere in the mount path makes glib class the mount system-internal, so
  # gvfs leaves it alone. ~/macbook stays a symlink, so every path, bookmark and tool
  # that already points there is unaffected.
  home.file."macbook".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.macbook";

  systemd.user.services.macbook-mount = {
    Unit = {
      Description = "SSHFS mount of the macbook's home at ~/.macbook";
      PartOf = [ "graphical-session.target" ];
      # 1Password holds the SSH key (IdentityAgent in ssh.nix); order after its
      # tray daemon so the agent socket exists on the first mount attempt. Only a
      # hint — a too-early attempt just fails and Restart retries.
      After = [ "graphical-session.target" "1password.service" ];
      Wants = [ "1password.service" ];
      "X-SwitchMethod" = "keep-old";
      # Keep retrying indefinitely (every RestartSec) when the Mac is unreachable,
      # instead of tripping systemd's default 5-in-10s start limit and giving up.
      StartLimitIntervalSec = 0;
    };
    Install.WantedBy = [ "graphical-session.target" ];
    Service = {
      Type = "simple";
      # Clear a stale mount left by an unclean stop, then ensure the mountpoint
      # exists. Leading `-` ignores failure (nothing mounted / dir absent).
      ExecStartPre = [
        "-/run/wrappers/bin/fusermount3 -uz %h/.macbook"
        "${pkgs.coreutils}/bin/mkdir -p %h/.macbook"
      ];
      # `bash -lc` rebuilds the full session PATH so sshfs finds fusermount3
      # (/run/wrappers/bin) and ssh — the early `systemd --user` PATH lacks both.
      # See the loginExec note in mixins/autostart.nix. sshfs resolves `macbook:`
      # (empty remote path = the Mac's home) via ~/.ssh/config, so no hardcoded
      # /Users path. ConnectTimeout makes an unreachable Mac fail fast (no hang);
      # reconnect + ServerAlive* recover across Mac sleep / network drops.
      ExecStart = ''${pkgs.bash}/bin/bash -lc 'exec ${pkgs.sshfs}/bin/sshfs -f -o reconnect -o ServerAliveInterval=15 -o ServerAliveCountMax=3 -o ConnectTimeout=10 -o idmap=user macbook: %h/.macbook' '';
      ExecStopPost = "-/run/wrappers/bin/fusermount3 -uz %h/.macbook";
      Restart = "on-failure";
      RestartSec = 30;
    };
  };

  # Files/Nautilus sidebar entries (GtkPlacesSidebar reads gtk-3.0/bookmarks even
  # under GTK4 Nautilus). Declarative — this file now owns the list, so the Macbook
  # mount sits alongside the previously hand-added folders. Add future bookmarks
  # here rather than through the Nautilus UI, which would be overwritten on switch.
  xdg.configFile."gtk-3.0/bookmarks".text = ''
    file://${config.home.homeDirectory}/macbook Macbook
    file://${config.home.homeDirectory}/Developer Developer
    file://${config.home.homeDirectory}/Pictures Pictures
    file://${config.home.homeDirectory}/Downloads Downloads
  '';
}
