# CanaryOrchestrator (canaryd + the canary CLI) — our own remote-dev-session
# orchestrator (Bun/TypeScript daemon + Zig ptyhost). Not fetchable the way
# canarycode.nix's upstream flake is: CanaryOrchestrator is a private repo and
# this box has no `access-tokens` entry for github.com in nix.conf, so
# `github:FormalSnake/CanaryOrchestrator` 404s. `builtins.getFlake` on the
# local checkout works everywhere the repo's own dev workflow already requires
# one (docs/development.md) — but it's an impure read, so switching this host
# needs `--impure` (see CanaryOrchestrator/docs/development.md "Installing via
# nix/home-manager").
#
# macOS is where canaryd actually runs (SPEC.md: the daemon + both client
# backends live on the Mac); NixOS is a client only, so it gets just the CLI
# (`canary status`/`logs`/`pair` against the SSH-tunneled daemon) with the
# background service left off.
#
# `homeDirectory` is derived from `builtins.currentSystem`, not `pkgs`/`config`
# (this file's own `default.nix` sets `home.homeDirectory` off
# `pkgs.stdenv.isDarwin` instead) — `imports` feeds into computing `config`,
# and this repo's home-manager is wired with `useGlobalPkgs = true`, so `pkgs`
# is itself derived from `config` here; referencing either from `imports` is
# an infinite-recursion trap.
{ lib, pkgs, ... }:
let
  homeDirectory = if builtins.currentSystem == "aarch64-darwin" then "/Users/kyandesutter" else "/home/kyandesutter";
  canary = builtins.getFlake "${homeDirectory}/Developer/CanaryOrchestrator";
in
{
  imports = [ canary.homeManagerModules.default ];

  canary = {
    enable = true;
    daemon.enable = lib.mkDefault pkgs.stdenv.isDarwin;
  };
}
