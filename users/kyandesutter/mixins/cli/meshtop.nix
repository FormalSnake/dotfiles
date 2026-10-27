{ config, inputs, lib, pkgs, ... }:
let
  home = config.home.homeDirectory;
  meshtop = lib.getExe config.programs.meshtop.package;
  # Tailscale Serve passes the browser's Host through, which the loopback
  # server would otherwise reject as a rebinding attempt.
  tailnetName = "macbook-pro-2.tailb24294.ts.net";
in
{
  # meshtop (github:FormalSnake/meshtop). Installed on all three hosts: the
  # TUI runs `meshtop agent` over ssh on the other two, and each agent reads
  # its activity rules from this same config. The mac's own hostname is
  # MacBook-Pro-2, so it needs `hostname` to be sampled in process there.
  imports = [ inputs.meshtop.homeModules.default ];

  programs.meshtop = {
    enable = true;
    hosts = [
      {
        name = "macbook";
        role = "dev";
        hostname = "MacBook-Pro-2";
      }
      {
        name = "g815";
        role = "builder";
      }
      {
        name = "e1504g";
        role = "client";
      }
    ];
    # Messages on the Linux hosts talks to BlueBubbles on the mac.
    ports."1234" = "bluebubbles";
    # Plan usage, read on whichever host runs the TUI. The second Claude
    # subscription lives in ~/.claude-pulse (see claude-code.nix).
    usage = [
      {
        kind = "claude";
        name = "claude";
      }
      {
        kind = "claude";
        name = "pulse";
        dir = "~/.claude-pulse";
      }
      { kind = "codex"; }
    ];
  };

  # The web manager, on the always-on mac only, reached from the phone and the
  # Linux hosts at https://macbook-pro-2.tailb24294.ts.net:8314. It stays on loopback without a
  # token; Serve keeps it tailnet-only. The mapping is reasserted every five
  # minutes for the same reason as t3code-serve: a dev-session `tailscale
  # serve` can replace it.
  launchd.agents = lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
    meshtop-web = {
      enable = true;
      config = {
        ProgramArguments = [ meshtop "serve" "--listen" "127.0.0.1:7314" "--allow-host" tailnetName ];
        # Jobs and deliveries started from the page inherit this.
        EnvironmentVariables.PATH = lib.concatStringsSep ":" [
          "${home}/.local/bin"
          "${config.home.profileDirectory}/bin"
          "/run/current-system/sw/bin"
          "/usr/bin"
          "/bin"
          "/usr/sbin"
          "/sbin"
        ];
        RunAtLoad = true;
        KeepAlive = true;
        ThrottleInterval = 30;
        StandardOutPath = "${home}/Library/Logs/meshtop-web.log";
        StandardErrorPath = "${home}/Library/Logs/meshtop-web.log";
      };
    };
    meshtop-web-serve = {
      enable = true;
      config = {
        ProgramArguments = [ "${pkgs.tailscale}/bin/tailscale" "serve" "--bg" "--https=8314" "http://127.0.0.1:7314" ];
        RunAtLoad = true;
        StartInterval = 300;
        StandardOutPath = "${home}/Library/Logs/meshtop-web-serve.log";
        StandardErrorPath = "${home}/Library/Logs/meshtop-web-serve.log";
      };
    };
  };
}
