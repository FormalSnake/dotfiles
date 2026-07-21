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
    ./mixins/omniwm.nix
    ./mixins/sketchybar.nix
  ];

  # macOS rebuild shortcut — the darwin counterpart to the g815 `rebuild`
  # (linux.nix). Drives the darwin flake through the justfile `r` recipe, which
  # already targets `#macbook`; `-f` points just at the repo so it's runnable
  # from any directory. Extra flags (e.g. --show-trace) pass through via $argv.
  programs.fish.functions.rebuild = {
    description = "Rebuild nix-darwin from the flake via `just r`, runnable from any directory";
    body = ''
      just -f ~/.config/nix/justfile r $argv
    '';
  };
}
