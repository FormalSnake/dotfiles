{
  system.defaults = {
    NSGlobalDomain = {
      AppleInterfaceStyle = "Dark";
      AppleShowAllExtensions = true;
      # Auto-hide the macOS menu bar — sketchybar owns the top edge now
      # (users/kyandesutter/mixins/sketchybar.nix). The native bar still reveals
      # on hover into the notch region.
      _HIHideMenuBar = true;
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
    };

    # Untyped preferences (no dedicated nix-darwin option). Written via
    # `defaults import` during activation — idempotent, no shell-out needed.
    CustomUserPreferences = {
      "NSGlobalDomain"."com.apple.mouse.scaling" = 1.5;
      "com.apple.screencapture" = {
        style = "window";
        showsClicks = true;
      };
      # Stage Manager — disabled; using plain macOS window management.
      "com.apple.WindowManager".GloballyEnabled = false;
    };

    dock = {
      autohide = true;
      orientation = "bottom";
      tilesize = 48;
      magnification = true;
      largesize = 57;
      minimize-to-application = true;
    };

    trackpad.TrackpadThreeFingerDrag = false;

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
}
