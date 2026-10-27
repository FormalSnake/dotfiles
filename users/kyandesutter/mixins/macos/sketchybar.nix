{ config, pkgs, lib, ... }:
let
  dir = "${config.home.homeDirectory}/.config/nix/users/kyandesutter/sketchybar";
  # sketchybar comes from Homebrew (FelixKratz/formulae): nixpkgs' build crashes
  # the cctools linker on this darwin (ld Trace/BPT trap). See systems/macbook/
  # homebrew.nix. The Lua side (interpreter + sbarlua module) stays on nix.
  sketchybarBin = "/opt/homebrew/bin/sketchybar";
  omniwmctl = "/Applications/OmniWM.app/Contents/MacOS/omniwmctl";
  # OmniWM 0.7.6 IPCSocketPath uses Application Support, not the legacy cache.
  omniwmSocket = "${config.home.homeDirectory}/Library/Application Support/com.barut.OmniWM/ipc.sock";
  # PathState wakes this on socket creation, but a stale socket is not readiness.
  # Probe the real protocol with a deadline and back off after failed connects.
  workspaceWatch = pkgs.writeShellScript "omniwm-sketchybar-watch" ''
    while [ -S ${lib.escapeShellArg omniwmSocket} ]; do
      if ${pkgs.coreutils}/bin/timeout 5 ${omniwmctl} ping >/dev/null 2>&1; then
        ${omniwmctl} watch active-workspace,windows-changed,layout-changed \
          --exec ${sketchybarBin} --trigger omniwm_update || true
        ${sketchybarBin} --trigger omniwm_update
      fi
      [ -S ${lib.escapeShellArg omniwmSocket} ] || exit 0
      /bin/sleep 30
    done
  '';

  # SbarLua is a native Lua module; nixpkgs builds it against Lua 5.5, so the
  # config runs under that exact interpreter and finds sketchybar.so via LUA_CPATH.
  luaModule = "${pkgs.sbarlua}/lib/lua/5.5/?.so";

  # sketchybar spawns the (long-lived) lua config, whose event callbacks shell out
  # to omniwmctl / jq / pmset / osascript / ipconfig. LaunchAgents inherit almost
  # no PATH, so pin one that resolves them all (lua5.5 first for the `env lua`
  # shebang; homebrew for omniwmctl's symlink).
  binPath = lib.concatStringsSep ":" [
    "${pkgs.lua5_5}/bin"
    "${config.home.profileDirectory}/bin"
    "/run/current-system/sw/bin"
    "/opt/homebrew/bin"
    "/usr/bin"
    "/usr/sbin" # ipconfig (wifi state)
    "/bin"
  ];
in
{
  home.packages = [ pkgs.jq ]; # sketchybar itself is from Homebrew (see above)

  # Whole config dir as one out-of-store symlink (git-tracked source), so the bar
  # can be edited and hot-reloaded live (sbar.hotload(true)) without a rebuild:
  # same pattern as the OmniWM config (mixins/macos/omniwm.nix). sketchybarrc keeps its
  # executable bit from git.
  xdg.configFile."sketchybar".source = config.lib.file.mkOutOfStoreSymlink dir;

  home.activation.sketchybarCache = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "$HOME/.cache/sketchybar"
  '';

  # The bar daemon. sketchybar auto-loads ~/.config/sketchybar/sketchybarrc, which
  # is a lua script: LUA_CPATH points `require("sketchybar")` at the sbarlua .so.
  launchd.agents.sketchybar = {
    enable = true;
    config = {
      ProgramArguments = [ sketchybarBin ];
      KeepAlive = true;
      RunAtLoad = true;
      ProcessType = "Interactive";
      EnvironmentVariables = {
        PATH = binPath;
        LUA_CPATH = "${luaModule};;";
      };
      StandardOutPath = "${config.home.homeDirectory}/.cache/sketchybar/out.log";
      StandardErrorPath = "${config.home.homeDirectory}/.cache/sketchybar/err.log";
    };
  };

  # Push OmniWM workspace/window/layout changes into the bar. `omniwmctl watch`
  # exits if IPC is down. Only keep it alive while the socket exists: otherwise
  # an absent OmniWM causes a failed process launch every five seconds.
  launchd.agents.omniwm-sketchybar-watch = {
    enable = true;
    config = {
      ProgramArguments = [ "${workspaceWatch}" ];
      KeepAlive.PathState."${omniwmSocket}" = true;
      RunAtLoad = true;
      ThrottleInterval = 5;
      EnvironmentVariables.PATH = binPath;
    };
  };
}
