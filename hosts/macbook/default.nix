{
  config,
  pkgs,
  lib,
  ...
}: {
  # Required Darwin system state version
  system.stateVersion = 6;

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
    CustomUserPreferences = {
      NSGlobalDomain."com.apple.mouse.linear" = true;
    };
    NSGlobalDomain = {
      AppleInterfaceStyle = "Dark";
      ApplePressAndHoldEnabled = false;
      AppleShowAllExtensions = true;
      KeyRepeat = 2;
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticDashSubstitutionEnabled = false;
      NSAutomaticQuoteSubstitutionEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = false;
      NSAutomaticWindowAnimationsEnabled = false;
      NSDocumentSaveNewDocumentsToCloud = false;
      NSNavPanelExpandedStateForSaveMode = true;
      PMPrintingExpandedStateForPrint = true;
      AppleICUForce24HourTime = true;
    };
    LaunchServices = {
      LSQuarantine = false;
    };
    dock = {
      orientation = "right";
      mru-spaces = false;
      tilesize = 48;
      autohide = true;
      expose-animation-duration = 0.15;
      show-recents = false;
      showhidden = true;
      persistent-apps = [
        "/Applications/Brave Browser.app"
        "/System/Applications/Calendar.app"
        "/Applications/Equibop.app"
        "/Applications/Ghostty.app"
        "/Applications/Spotify.app"
      ];
      wvous-bl-corner = 11;
      wvous-br-corner = 2;
      wvous-tl-corner = 1;
      wvous-tr-corner = 1;
    };
    trackpad = {
      TrackpadRightClick = true;
      TrackpadThreeFingerDrag = true;
      Clicking = true;
    };
    finder = {
      AppleShowAllFiles = true;
      CreateDesktop = false;
      FXDefaultSearchScope = "SCcf";
      FXEnableExtensionChangeWarning = false;
      FXPreferredViewStyle = "Nlsv";
      QuitMenuItem = true;
      ShowPathbar = true;
      ShowStatusBar = true;
      _FXShowPosixPathInTitle = true;
      _FXSortFoldersFirst = true;
    };
    loginwindow.GuestEnabled = false;
    screencapture = {
      location = "~/Pictures/screenshots";
      type = "png";
      disable-shadow = true;
    };
    screensaver.askForPasswordDelay = 10;
  };

  # Fonts configuration
  fonts.packages = with pkgs; [
    nerd-fonts.geist-mono
  ];

  system.primaryUser = "kyandesutter";

  # Any host-specific overrides can be placed here
  networking.hostName = "macbook";

  # Import homebrew configuration
  imports = [
    ./homebrew.nix
  ];
}
