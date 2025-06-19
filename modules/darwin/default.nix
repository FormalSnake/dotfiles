{
  config,
  pkgs,
  lib,
  ...
}: {
  # macOS specific system configuration
  nixpkgs.hostPlatform = config.nixpkgs.system;

  # Enable experimental Nix command and flakes
  nix.settings.experimental-features = "nix-command flakes";

  # Touch ID support for sudo
  security.pam.services.sudo_local.touchIdAuth = true;

  # System defaults
  system.keyboard = {
    enableKeyMapping = true;
    remapCapsLockToEscape = true;
  };

  # macOS Applications management
  system.activationScripts.applications.text = let
    env = pkgs.buildEnv {
      name = "system-applications";
      paths = config.environment.systemPackages;
      pathsToLink = "/Applications";
    };
  in
    lib.mkForce ''
      echo "setting up /Applications..." >&2
      rm -rf /Applications/Nix\ Apps
      mkdir -p /Applications/Nix\ Apps
      find ${env}/Applications -maxdepth 1 -type l -exec readlink '{}' + |
      while read -r src; do
        app_name=$(basename "$src")
        echo "copying $src" >&2
        ${pkgs.mkalias}/bin/mkalias "$src" "/Applications/Nix Apps/$app_name"
      done
    '';

  # Set macOS defaults that are common to all darwin machines
  system.defaults = {
    dock = {
      autohide = true;
      orientation = "right";
      show-recents = false;
      showhidden = true;
      mru-spaces = false;
      tilesize = 48;
    };
    finder = {
      FXPreferredViewStyle = "clmv";
      _FXShowPosixPathInTitle = true;
    };
    loginwindow.GuestEnabled = false;
    screencapture.location = "~/Pictures/screenshots";
    screensaver.askForPasswordDelay = 10;
    NSGlobalDomain = {
      AppleICUForce24HourTime = true;
      AppleInterfaceStyle = "Dark";
    };
  };

  # macOS system version
  system.stateVersion = 5;

  # Homebrew module common to all darwin machines
  imports = [./homebrew.nix];
}

