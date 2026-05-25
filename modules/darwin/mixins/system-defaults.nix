{
  system.defaults = {
    NSGlobalDomain = {
      AppleInterfaceStyle = "Dark";
      AppleShowAllExtensions = true;
      KeyRepeat = 2;
      ApplePressAndHoldEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = false;
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticDashSubstitutionEnabled = false;
      NSAutomaticPeriodSubstitutionEnabled = true;
      NSAutomaticQuoteSubstitutionEnabled = false;
      NSNavPanelExpandedStateForSaveMode = true;
      "com.apple.trackpad.scaling" = 0.6875;
      "com.apple.swipescrolldirection" = true;
      # `com.apple.mouse.scaling` is not a typed nix-darwin option in this version —
      # set via activation script below.
    };

    dock = {
      autohide = true;
      orientation = "left";
      tilesize = 48;
      magnification = true;
      largesize = 57;
      minimize-to-application = true;
    };

    finder = {
      AppleShowAllFiles = true;
      ShowPathbar = true;
      ShowStatusBar = true;
      FXPreferredViewStyle = "clmv";
      FXDefaultSearchScope = "SCcf";
    };

    screencapture = {
      location = "~/Pictures/screenshots";
      type = "png";
      disable-shadow = true;
      show-thumbnail = true;
    };
  };

  # Settings without typed nix-darwin options — applied via `defaults write`
  # during system activation. Idempotent.
  system.activationScripts.extraUserDefaults.text = ''
    echo "Applying extra user defaults (mouse scaling, screencapture style)..." >&2
    sudo -u kyandesutter defaults write NSGlobalDomain com.apple.mouse.scaling -float 1.5
    sudo -u kyandesutter defaults write com.apple.screencapture style -string "window"
    sudo -u kyandesutter defaults write com.apple.screencapture showsClicks -bool true
  '';
}
