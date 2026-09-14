{
  programs.ghostty = {
    enable = true;
    # The binary is the `ghostty` Homebrew cask (nixpkgs has no darwin build),
    # so this only writes ~/.config/ghostty/config.
    package = null;
    enableFishIntegration = false;

    settings = {
      # The Nerd Font patch, so box-drawing, powerline segments and the fish
      # prompt's OS logo come out of the primary face with no fallback chain.
      # The "Mono" cut: CoreText won't report the plain family as fixed-pitch,
      # so it never appears in `ghostty +list-fonts` and an unresolvable
      # font-family falls back to ghostty's own default without saying so.
      font-family = "GeistMono Nerd Font Mono";
      font-size = 10;
      # Regular reads thin at this size. Medium is a real cut in the family, so
      # this picks a drawn weight rather than the synthetic thickening
      # font-thicken would apply. Bold still resolves to the Bold face.
      font-style = "Medium";

      cursor-style = "block";
      cursor-style-blink = false;
      shell-integration = "fish";
      # `ssh-terminfo` copies the xterm-ghostty terminfo to remotes over a side
      # connection and stalls ssh at "Setting up xterm-ghostty terminfo".
      shell-integration-features = "cursor,sudo,title,ssh-env,no-ssh-terminfo";

      background-opacity = 1.0;
      background-blur-radius = 0;

      mouse-hide-while-typing = true;

      window-colorspace = "display-p3";
      confirm-close-surface = false;
      resize-overlay = "never";

      clipboard-read = "allow";
      clipboard-write = "allow";

      keybind = [
        "shift+enter=text:\\x1b\\r"
        "global:cmd+shift+space=toggle_quick_terminal"
      ];

      # Follows the system appearance. The names carry a space, which the
      # `light:…,dark:…` syntax handles (it only splits on the comma).
      theme = "light:Flexoki Light,dark:Flexoki Dark";
      macos-titlebar-style = "tabs";
    };
  };
}
