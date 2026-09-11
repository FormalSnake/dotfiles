{ pkgs, lib, config, ... }:
let
  # Rakuten TV refuses to play in any browser that reports Linux: the player
  # returns "you cannot watch movies on GNU/Linux" before a licence request is
  # ever made, so the CDM situation is beside the point until the UA lies.
  # Helium can't be the one to lie: it is the daily driver with a synced
  # profile, and a global UA override would follow every site. Hence a second,
  # single-purpose browser.
  #
  # Google Chrome rather than another ungoogled build: it ships Google's own
  # Widevine and keeps it component-updated, which is the combination Rakuten's
  # licence server is least likely to reject once the UA check is past. Linux
  # Widevine is L3, so expect 720p at best.
  chrome = pkgs.google-chrome;

  # UA major version tracks the real binary; a stale number is itself a
  # fingerprint, and Rakuten gates on minimum Chrome versions.
  ua =
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) "
    + "Chrome/${lib.versions.major chrome.version}.0.0.0 Safari/537.36";

  profile = "${config.home.homeDirectory}/.config/rakuten-chrome";

  rakuten = pkgs.writeShellScriptBin "rakuten" ''
    exec ${chrome}/bin/google-chrome-stable \
      --user-data-dir=${lib.escapeShellArg profile} \
      --user-agent=${lib.escapeShellArg ua} \
      --enable-features=AcceleratedVideoDecodeLinuxGL \
      --class=rakuten \
      "''${@:-https://www.rakuten.tv/}"
  '';
in
{
  home.packages = [ rakuten ];

  # Not the default browser and not in the http handler list: this entry exists
  # only so the launcher can start it.
  xdg.desktopEntries.rakuten = {
    name = "Rakuten TV";
    genericName = "Video streaming";
    exec = "${rakuten}/bin/rakuten %U";
    icon = "google-chrome";
    terminal = false;
    categories = [ "AudioVideo" "Video" ];
    settings.StartupWMClass = "rakuten";
  };
}
