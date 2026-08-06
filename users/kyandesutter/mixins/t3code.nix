{ config, lib, pkgs, inputs, ... }:
let
  # t3code ships two binaries: `t3` (the headless server/CLI) and
  # `t3code-desktop` (the Electron client). nixpkgs wraps them with a PATH
  # prefix holding the agent and VCS CLIs the server may spawn, which is
  # load-bearing here: launchd starts the server with a bare PATH. Claude comes
  # from the same claude-code-nix input as mixins/claude-code.nix so the GUI and
  # the terminal drive one CLI version. Codex is off (no OpenAI CLI on these
  # hosts); git and gh stay on by default.
  t3code = pkgs.t3code.override {
    enableClaude = true;
    claude-code = inputs.claude-code-nix.packages.${pkgs.system}.default;
    enableOpencode = true;
    enableCodex = false;
  };

  # `t3 serve` binds exactly one address, and the tailnet address only exists
  # once tailscaled is up, so resolve it at start instead of pinning 100.x.y.z
  # into the store. Binding the tailnet IP keeps the server off the LAN and off
  # every public interface: pairing tokens are the only authentication.
  serve = pkgs.writeShellScript "t3code-serve" ''
    set -euo pipefail
    exec ${lib.getExe' t3code "t3"} serve \
      --no-browser \
      --host "$(${lib.getExe pkgs.tailscale} ip -4 | head -1)"
  '';
in
{
  home.packages = [ t3code ];

  # The macbook hosts the agents; the e1504g runs the desktop client against it
  # over the tailnet. Upstream's own background service (`t3 service install`)
  # is Linux/systemd only, so drive it from launchd here. A user agent, not a
  # daemon: Claude Code reads its credentials from the login keychain, and the
  # provider sessions belong to this login session.
  launchd.agents = lib.optionalAttrs pkgs.stdenv.isDarwin {
    t3code-serve = {
      enable = true;
      config = {
        ProgramArguments = [ "${serve}" ];
        RunAtLoad = true;
        KeepAlive = true;
        # tailscaled often has no address yet at login; the script exits
        # non-zero and launchd retries on this interval until it does.
        ThrottleInterval = 30;
        WorkingDirectory = config.home.homeDirectory;
        EnvironmentVariables.PATH = lib.concatStringsSep ":" [
          "${config.home.profileDirectory}/bin"
          "/run/current-system/sw/bin"
          "/opt/homebrew/bin"
          "/usr/bin"
          "/bin"
          "/usr/sbin"
          "/sbin"
        ];
        StandardOutPath = "${config.home.homeDirectory}/Library/Logs/t3code-serve.log";
        StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/t3code-serve.log";
      };
    };
  };
}
