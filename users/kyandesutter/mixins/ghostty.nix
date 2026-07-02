{ config, lib, pkgs, ... }:
let
  isDarwin = pkgs.stdenv.isDarwin;
in
{
  programs.ghostty = {
    enable = true;
    # ghostty is not packaged on darwin in nixpkgs; there the binary comes from
    # the `ghostty` homebrew cask and we use programs.ghostty only for the
    # declarative ~/.config/ghostty/config. On Linux ghostty IS packaged, so use
    # the real package.
    #
    # Theming differs per platform (see the `theme` line below). On Linux the
    # colours are wallpaper-derived: Noctalia renders the live palette into
    # ~/.config/ghostty/themes/Matugen and SIGUSR2-reloads ghostty (see the
    # `ghostty` user template in mixins/noctalia.nix). On macOS (no Noctalia) we
    # stay on Catppuccin. Since catppuccin.autoEnable is now false
    # (mixins/catppuccin.nix), the module no longer auto-installs ghostty theme
    # files — the Darwin branch installs them explicitly below.
    package = if isDarwin then null else pkgs.ghostty;
    enableFishIntegration = false;

    settings = {
      font-family = "GeistMono Nerd Font";
      font-size = 10;

      cursor-style = "block";
      cursor-style-blink = false;
      # Original file set this twice (`no-cursor` then `true`); preserve the
      # last-wins behaviour with a single value.
      shell-integration = "fish";
      # `true` enables every feature, including `ssh-terminfo`, which copies the
      # xterm-ghostty terminfo to remotes by opening a side connection and running
      # `tic`. On the Mac that step stalls and ssh appears to hang at
      # "Setting up xterm-ghostty terminfo on macbook...". Keep the local features
      # (cursor/sudo/title) and lightweight `ssh-env`, but drop `ssh-terminfo`.
      shell-integration-features = "cursor,sudo,title,ssh-env,no-ssh-terminfo";

      background-opacity = 0.9;
      background-blur-radius = 32;

      mouse-hide-while-typing = true;

      window-colorspace = "display-p3";
      confirm-close-surface = false;
      resize-overlay = "never";

      clipboard-read = "allow";
      clipboard-write = "allow";

      # shift+enter helper is cross-platform; the cmd-based global quick-terminal
      # toggle is macOS-only (the `cmd` key doesn't exist on the Linux build).
      keybind = [
        "shift+enter=text:\\x1b\\r"
      ] ++ lib.optionals isDarwin [ "global:cmd+shift+space=toggle_quick_terminal" ];

      # Linux: the single dynamic "Matugen" theme Noctalia writes (it rewrites the
      # file on every light/dark flip, so one name covers both modes). macOS:
      # follow the system appearance with Catppuccin (latte ↔ flavor).
      # NOTE (Linux cold start): the Matugen file only exists once Noctalia has
      # generated a wallpaper palette — populate ~/Pictures/Wallpapers/{light,dark}
      # or ghostty starts themeless until the first palette is generated.
      theme =
        if isDarwin then
          "light:catppuccin-latte,dark:catppuccin-${config.catppuccin.flavor}"
        else
          "Matugen";
    }
    # macos-titlebar-style is rejected by the Linux build.
    // lib.optionalAttrs isDarwin { macos-titlebar-style = "tabs"; };
  };

  # macOS Catppuccin theme files. With catppuccin.autoEnable = false the module
  # no longer installs any ghostty theme file, so install both the latte (Light)
  # and active-flavor (Dark) files explicitly. Linux doesn't need these — Noctalia
  # writes the dynamic "Matugen" theme at runtime.
  xdg.configFile = lib.mkIf isDarwin (
    {
      "ghostty/themes/catppuccin-latte".source =
        "${config.catppuccin.sources.ghostty}/catppuccin-latte.conf";
    }
    // lib.optionalAttrs (config.catppuccin.flavor != "latte") {
      "ghostty/themes/catppuccin-${config.catppuccin.flavor}".source =
        "${config.catppuccin.sources.ghostty}/catppuccin-${config.catppuccin.flavor}.conf";
    }
  );

  # On macOS the ghostty binary is a Homebrew cask, so nixpkgs has no ghostty
  # package and an incoming SSH session — TERM=xterm-ghostty, sent from the Linux
  # box — can't find the terminfo entry, so full-screen apps error with "unknown
  # terminal type". Compile the captured source (./xterm-ghostty.terminfo, from
  # `infocmp -x xterm-ghostty`) into ~/.terminfo using the *system* tic so the
  # output matches Apple's ncurses readers. ~/.terminfo is searched
  # unconditionally, so no env var is needed. This is the declarative stand-in
  # for ghostty's `ssh-terminfo` shell-integration feature, disabled above
  # because it hung on connect.
  home.activation.ghosttyTerminfo = lib.mkIf isDarwin (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ -x /usr/bin/tic ]; then
        run /usr/bin/tic -x -o "$HOME/.terminfo" ${./xterm-ghostty.terminfo} || true
      fi
    ''
  );
}
