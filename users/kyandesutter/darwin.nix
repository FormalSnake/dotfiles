{
  # macOS-only home mixins. Wired on the macbook host via
  # self.homeModules.kyandesutter-darwin (kept out of ./default.nix so imports
  # don't depend on the platform).
  imports = [
    # Disabled for a lighter dev host — using Apple's Stage Manager instead of
    # aerospace tiling. Configs are kept; just not imported.
    # ./mixins/aerospace.nix
    ./mixins/android.nix
    ./mixins/hammerspoon.nix
    ./mixins/lynk-browser.nix
  ];
}
