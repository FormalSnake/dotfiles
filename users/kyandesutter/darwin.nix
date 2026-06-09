{
  # macOS-only home mixins. Wired on the macbook host via
  # self.homeModules.kyandesutter-darwin (kept out of ./default.nix so imports
  # don't depend on the platform).
  imports = [
    ./mixins/aerospace.nix
    ./mixins/karabiner.nix
    ./mixins/hammerspoon.nix
    ./mixins/jankyborders.nix
    ./mixins/rift.nix
    ./mixins/lynk-browser.nix
  ];
}
