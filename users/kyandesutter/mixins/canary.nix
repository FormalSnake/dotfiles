# CanaryOrchestrator (canaryd + the canary CLI + the Linux desktop launcher) —
# our own remote-dev-session orchestrator. Consumed as a pure git+ssh flake
# input (see flake.nix `canary`), which replaces the impure
# `builtins.getFlake` local-checkout import dropped in af8161e7.
#
# The daemon service is DISABLED on every host on purpose: the Mac runs
# canaryd via `canary install`'s own LaunchAgent (kept manually managed so a
# rebuild never restarts it mid-session), and the NixOS boxes are clients
# only. What this actually delivers everywhere is the `canary` CLI, and on
# Linux the `canary-desktop` launcher + XDG entry, which runs the GUI from
# the source checkout at ~/Developer/CanaryOrchestrator (the module's
# default; the GUI itself isn't nix-packaged yet).
{ inputs, ... }:
{
  imports = [ inputs.canary.homeManagerModules.default ];

  canary = {
    enable = true;
    daemon.enable = false;
  };
}
