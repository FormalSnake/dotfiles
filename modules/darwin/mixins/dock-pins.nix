{ config, ... }:
let
  # HM-managed GUI apps land in this trampoline dir (symlinks into the nix
  # store). Use this prefix for any dock pin whose .app comes from
  # home-manager so the path tracks the active home generation.
  hmApps = "${config.users.users.kyandesutter.home}/Applications/Home Manager Apps";

  # Brew casks, system apps, and manual /Applications installs — paths are
  # stable so we hardcode them.
  brewApps = [
    "/Applications/LaunchOS.app"
    "/Applications/Helium.app"
    "/Applications/Ghostty.app"
    "/Applications/OrbStack.app"
    "/Applications/Obsidian.app"
    "/Applications/Claude.app"
    "/Applications/Equibop.app"
    "/Applications/Beeper Desktop.app"
    "/System/Applications/Messages.app"
    "/Applications/Spotify.app"
  ];

  # HM / nix-installed apps — resolved dynamically against the current HM
  # generation.
  nixApps = [
    "${hmApps}/PrismLauncher.app"
  ];
in
{
  system.defaults.dock.persistent-apps = brewApps ++ nixApps;
}
