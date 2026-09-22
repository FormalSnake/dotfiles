{ config, pkgs, ... }:
let
  home = config.users.users.kyandesutter.home;
in
{
  # Publishes CouchDB (127.0.0.1:5984) at https://<mac>.<tailnet>.ts.net/ for
  # the LiveSync plugin on the g815, iPhone and iPad. Port 443 is required:
  # iOS Obsidian only syncs to a non-localhost remote over HTTPS with a valid
  # cert, and the plugin's remote URI on every device has no port.
  # `tailscale serve --bg 4322` run from a dev session silently replaces the
  # "/" handler on 443 (2026-09: sync stopped for every remote device), so
  # this reasserts the mapping at login and every five minutes. The nix
  # `tailscale` CLI is used on purpose: it reaches the App Store daemon over
  # its local socket (with a version-skew warning), whereas the app's own
  # CLI tries to launch the GUI and fails under launchd (CLIError 3).
  launchd.user.agents.obsidian-livesync-serve = {
    serviceConfig = {
      Label = "kyan.obsidian-livesync-serve";
      ProgramArguments = [
        "${pkgs.tailscale}/bin/tailscale"
        "serve"
        "--bg"
        "--https=443"
        "http://127.0.0.1:5984"
      ];
      RunAtLoad = true;
      StartInterval = 300;
      StandardOutPath = "${home}/Library/Logs/obsidian-livesync-serve.log";
      StandardErrorPath = "${home}/Library/Logs/obsidian-livesync-serve.log";
    };
  };
}
