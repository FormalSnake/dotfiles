{ config, lib, pkgs, ... }:
let
  home = config.users.users.kyandesutter.home;
  # Zero-dependency bundled CLI; pin the exact npm tarball so the daemon never
  # depends on a project's node_modules (rewritten by bun install) or a
  # GC-able dev-shell node. Keep in sync with the portless devDependency in
  # consuming repos (pre-1.0 releases may change the ~/.portless state format).
  portless = pkgs.fetchzip {
    url = "https://registry.npmjs.org/portless/-/portless-0.15.4.tgz";
    hash = "sha256-7SIqXt/4/pi4dqN3HVySIGA4+77iy6bQWLh64nbisbc=";
  };
in
{
  # Portless HTTPS proxy from boot, as root. Root is not optional here:
  # Tailscale serve (CouchDB LiveSync) holds *:443 from login, and macOS only
  # lets root bind a specific address (127.0.0.1:443) over another user's
  # wildcard socket. Ad-hoc sudo starts from dev sessions died on every
  # reboot/rebuild and left root-owned droppings in ~/.portless. This daemon
  # replaces them (same flags portless's own `service install` would write).
  launchd.daemons.portless-proxy = {
    serviceConfig = {
      Label = "kyan.portless-proxy";
      ProgramArguments = [
        "${pkgs.nodejs_24}/bin/node"
        "${portless}/dist/cli.js"
        "proxy"
        "start"
        "--foreground"
        "--port"
        "443"
        "--https"
        "--skip-trust"
      ];
      EnvironmentVariables = {
        # SUDO_* + HOME make portless resolve state to the invoking user, as
        # its sudo auto-elevation path does (resolveUserContext in cli.js).
        HOME = home;
        SUDO_USER = "kyandesutter";
        SUDO_UID = "502";
        SUDO_GID = "20";
        PORTLESS_STATE_DIR = "${home}/.portless";
        PORTLESS_PORT = "443";
        PORTLESS_HTTPS = "1";
        PORTLESS_LAN = "0";
        PORTLESS_WILDCARD = "0";
        PATH = lib.makeBinPath [ pkgs.openssl ] + ":/usr/bin:/bin:/usr/sbin:/sbin";
      };
      RunAtLoad = true;
      KeepAlive = true;
      ThrottleInterval = 5;
      StandardOutPath = "${home}/.portless/service.log";
      StandardErrorPath = "${home}/.portless/service.log";
    };
  };
}
