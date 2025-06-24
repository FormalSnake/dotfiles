{
  config,
  pkgs,
  lib,
  userConfig,
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
      persistent-apps = [];
      wvous-bl-corner = 1;
      wvous-br-corner = 1;
      wvous-tl-corner = 1;
      wvous-tr-corner = 1;
    };
    trackpad = {
      TrackpadRightClick = true;
      TrackpadThreeFingerDrag = true;
      Clicking = true;
    };
    finder = {
      # FXPreferredViewStyle = "clmv";
      # _FXShowPosixPathInTitle = true;
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

  # macOS system version
  system.stateVersion = 6;

  # Homebrew module common to all darwin machines
  imports = [./homebrew.nix];
}
