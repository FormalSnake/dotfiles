def dock(*apps):
    return [{"tile-data": {"file-data": {"_CFURLString": a, "_CFURLStringType": 0}}} for a in apps]

DEFAULTS = {
    "NSGlobalDomain": {
        "AppleInterfaceStyle": "Dark",
        "AppleShowAllExtensions": True,
        "_HIHideMenuBar": True,
        "KeyRepeat": 2,
        "ApplePressAndHoldEnabled": False,
        "NSAutomaticSpellingCorrectionEnabled": False,
        "NSAutomaticCapitalizationEnabled": False,
        "NSAutomaticDashSubstitutionEnabled": False,
        "NSAutomaticPeriodSubstitutionEnabled": True,
        "NSAutomaticQuoteSubstitutionEnabled": False,
        "NSNavPanelExpandedStateForSaveMode": True,
        "com.apple.trackpad.scaling": 0.6875,
        "com.apple.swipescrolldirection": True,
        "com.apple.mouse.scaling": 1.5,
    },
    "com.apple.dock": {
        "autohide": True,
        "orientation": "bottom",
        "tilesize": 48,
        "magnification": True,
        "largesize": 57,
        "minimize-to-application": True,
        "persistent-apps": dock(
            "/Applications/Helium.app",
            "/Applications/Ghostty.app",
            "/Applications/OrbStack.app",
            "/System/Applications/Calendar.app",
            "/System/Applications/Messages.app",
        ),
    },
    "com.apple.finder": {
        "AppleShowAllFiles": True,
        "ShowPathbar": True,
        "ShowStatusBar": True,
        "FXPreferredViewStyle": "clmv",
        "FXDefaultSearchScope": "SCcf",
    },
    "com.apple.screencapture": {
        "location": "~/Pictures/screenshots",
        "type": "png",
        "disable-shadow": True,
        "show-thumbnail": True,
        "style": "window",
        "showsClicks": True,
    },
    # Reached over ssh and VNC: a password gate or screen saver only gets in the way.
    "com.apple.screensaver": {"askForPassword": False, "idleTime": 0},
    "com.apple.AppleMultitouchTrackpad": {"TrackpadThreeFingerDrag": False},
    "com.apple.driver.AppleBluetoothMultitouch.trackpad": {"TrackpadThreeFingerDrag": False},
    "com.apple.WindowManager": {"GloballyEnabled": False},
    "com.apple.dt.Xcode": {"IDECustomDerivedDataLocation": "/Volumes/Kyan Drive/DerivedData"},
}

# An unattended reboot once left it at the login window, asleep within minutes and unreachable.
SYSTEM = [defaults(d, k, v) for d, keys in DEFAULTS.items() for k, v in keys.items()] + [
    setting("pmset", "sleep", 0),
    setting("pmset", "womp", 1),
    setting("systemsetup", "restartfreeze", True),
    setting("systemsetup", "remotelogin", True),
    # It drops inbound UDP to ad-hoc-signed binaries (mosh), and its allow list stopped working in
    # 26.5.2. Tailscale and the network edge gate inbound instead.
    setting("firewall", "globalstate", False),
    # An update reboot parks the machine at the FileVault screen.
    defaults("com.apple.SoftwareUpdate", "AutomaticallyInstallMacOSUpdates", False, system = True),
    # Screen Sharing would lock the screen again when a session that unlocked it ends.
    defaults("com.apple.RemoteManagement", "RestoreMachineState", False, system = True),
]
