{ config, lib, pkgs, ... }:
let
  home = config.home.homeDirectory;

  # claude comes from programs.claude-code (claude-code-nix), so the wrapper's
  # bundled codex is dropped rather than shadowing nothing useful.
  t3code = pkgs.t3code.override { enableCodex = false; };

  port = 3773;
  httpsPort = 8773;

  # The server only binds loopback; tailnet clients reach it through Tailscale
  # Serve HTTPS, which the mobile app and app.t3.codes require anyway. 443 is
  # CouchDB's on the mac (obsidian-livesync-serve.nix), so t3 gets its own
  # port. `t3 serve --tailscale-serve` is not used: it edits the serve config
  # itself, and a stray `tailscale serve` on 443 has already broken LiveSync
  # once.
  serveArgs = [
    "${pkgs.tailscale}/bin/tailscale"
    "serve"
    "--bg"
    "--https=${toString httpsPort}"
    "http://127.0.0.1:${toString port}"
  ];

  serverArgs = [
    (lib.getExe' t3code "t3")
    "serve"
    "--host"
    "127.0.0.1"
    "--port"
    (toString port)
    "${home}/Developer"
  ];

  # Provider CLIs (claude, gh, git) must resolve from a service environment
  # that has no login shell behind it.
  path = lib.concatStringsSep ":" [
    "${config.home.profileDirectory}/bin"
    "/run/current-system/sw/bin"
    "/usr/bin"
    "/bin"
  ];
in
{
  home.packages = [ t3code ];

  launchd.agents = lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
    t3code = {
      enable = true;
      config = {
        ProgramArguments = serverArgs;
        RunAtLoad = true;
        KeepAlive = true;
        WorkingDirectory = home;
        EnvironmentVariables = {
          PATH = path;
          SHELL = lib.getExe pkgs.fish;
        };
        StandardOutPath = "${home}/Library/Logs/t3code.log";
        StandardErrorPath = "${home}/Library/Logs/t3code.log";
      };
    };

    # Reasserted every five minutes for the same reason as the LiveSync
    # mapping: any dev-session `tailscale serve` can replace it.
    t3code-serve = {
      enable = true;
      config = {
        ProgramArguments = serveArgs;
        RunAtLoad = true;
        StartInterval = 300;
        StandardOutPath = "${home}/Library/Logs/t3code-serve.log";
        StandardErrorPath = "${home}/Library/Logs/t3code-serve.log";
      };
    };
  };

  systemd.user = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
    services.t3code = {
      Unit = {
        Description = "T3 Code server";
        After = [ "network-online.target" ];
      };
      Service = {
        ExecStart = lib.escapeShellArgs serverArgs;
        WorkingDirectory = home;
        Environment = [
          "PATH=${path}"
          "SHELL=${lib.getExe pkgs.fish}"
        ];
        Restart = "always";
        RestartSec = 5;
      };
      Install.WantedBy = [ "default.target" ];
    };

    # Needs tailscale operator rights, which modules/nixos/mixins/hyprland.nix
    # grants kyandesutter.
    services.t3code-serve = {
      Unit.Description = "Publish the T3 Code server over Tailscale Serve";
      Service = {
        Type = "oneshot";
        ExecStart = lib.escapeShellArgs serveArgs;
      };
    };
    timers.t3code-serve = {
      Timer = {
        OnStartupSec = 10;
        OnUnitActiveSec = 300;
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
