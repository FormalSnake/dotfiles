{ ... }:
{
  # Brew casks, system apps, and manual /Applications installs — paths are stable
  # so we hardcode them. (PrismLauncher was dropped: it has no aarch64-darwin
  # build — see the note in users/kyandesutter/linux.nix — so its pin was dead.)
  system.defaults.dock.persistent-apps = [
    "/Applications/LaunchOS.app"
    "/Applications/Helium.app"
    "/Applications/Ghostty.app"
    "/Applications/OrbStack.app"
    "/System/Applications/Calendar.app"
    "/System/Applications/Messages.app"
  ];
}
