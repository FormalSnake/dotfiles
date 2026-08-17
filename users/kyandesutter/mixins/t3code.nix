{ config, lib, pkgs, inputs, ... }:
let
  packaging = "${inputs.nixpkgs-t3code}/pkgs/by-name/t3/t3code";

  # Upstream's nightly channel, not a stable tag. Bumping means a new tag plus
  # fresh `hash` values for the source and the pnpm store — take them from the
  # build failure, they are not derivable.
  version = "0.0.34-nightly.20260811.1064";

  unwrapped = (pkgs.callPackage "${packaging}/unwrapped.nix" { }).overrideAttrs (
    final: prev: {
      inherit version;

      src = pkgs.fetchFromGitHub {
        owner = "pingdotgg";
        repo = "t3code";
        tag = "v${version}";
        hash = "sha256-36xkZx5W2nC2V2SZq1c30gIAqwa/9Zpnou20L5eUrDY=";
      };

      # fetchPnpmDeps closes over src, so the pinned nixpkgs hash cannot carry
      # over; rebuild the fetcher against the nightly tree. The store is keyed
      # per system: the fetcher passes `--force` to pull dependencies for every
      # platform, yet darwin and linux still resolve to different trees, so
      # nixpkgs' single upstream hash only ever matches one of them. Both hosts
      # need their own value, each read off that host's build failure.
      pnpmDeps = pkgs.fetchPnpmDeps {
        inherit (final)
          pname
          version
          src
          pnpmWorkspaces
          ;
        pnpm = pkgs.pnpm_11;
        fetcherVersion = 4;
        hash = {
          aarch64-darwin = "sha256-92sXIntCkvzTYWpcjl7bte03xdE0QtToRn1Gg74t2Xw=";
          x86_64-linux = "sha256-i/K5bj7CS7PGIX5hfayxAJ7ngNib92w3SDKGXTVWccA=";
        }.${pkgs.stdenv.hostPlatform.system};
      };
    }
  );

  # t3code ships two binaries: `t3` (the headless server/CLI) and
  # `t3code-desktop` (the Electron client). nixpkgs wraps them with a PATH
  # prefix holding the agent and VCS CLIs the server may spawn, which is
  # load-bearing here: launchd starts the server with a bare PATH. Claude comes
  # from the same claude-code-nix input as mixins/claude-code.nix so the GUI and
  # the terminal drive one CLI version. Codex is off (no OpenAI CLI on these
  # hosts); git and gh stay on by default.
  t3code = pkgs.callPackage "${packaging}/package.nix" {
    t3code-unwrapped = unwrapped;
    enableClaude = true;
    claude-code = inputs.claude-code-nix.packages.${pkgs.system}.default;
    enableOpencode = true;
    enableCodex = false;
  };

  # Electron picks its safeStorage backend from XDG_CURRENT_DESKTOP, and
  # "Hyprland" is not a name it knows, so it falls back to the "basic" store,
  # which Electron 36+ reports as unavailable. The app then can't write its
  # connection catalog ("Desktop secure storage is unavailable in this system
  # context") and no environment can be saved. gnome-keyring already owns
  # org.freedesktop.secrets on the Linux hosts
  # (modules/nixos/mixins/hyprland.nix), so name that backend explicitly.
  # macOS has a keychain and needs none of it.
  desktop = if !pkgs.stdenv.isLinux then t3code else pkgs.symlinkJoin {
    name = "t3code-${t3code.version}";
    paths = [ t3code ];
    nativeBuildInputs = [ pkgs.makeBinaryWrapper ];
    postBuild = ''
      wrapProgram "$out/bin/t3code-desktop" --add-flags --password-store=gnome-libsecret
    '';
  };

  # `t3 serve` binds exactly one address, and the tailnet address only exists
  # once tailscaled is up, so resolve it at start instead of pinning 100.x.y.z
  # into the store. Binding the tailnet IP keeps the server off the LAN and off
  # every public interface: pairing tokens are the only authentication.
  # Clients store the endpoint URL, port included, so the port has to survive a
  # restart: left to itself the server takes an arbitrary free one and every
  # paired client fails to reconnect. 3773 is what the clients already hold.
  serve = pkgs.writeShellScript "t3code-serve" ''
    set -euo pipefail
    exec ${lib.getExe' t3code "t3"} serve \
      --no-browser \
      --port 3773 \
      --host "$(${lib.getExe pkgs.tailscale} ip -4 | head -1)"
  '';
in
{
  home.packages = [ desktop ];

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
