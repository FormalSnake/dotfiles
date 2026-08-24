{ lib, pkgs, ... }:
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
    # colours are wallpaper-derived: DMS renders the live matugen palette into
    # ~/.config/ghostty/themes/Matugen and SIGUSR2-reloads ghostty (see the
    # `ghostty` user template in mixins/dms.nix). On macOS (no DMS) we
    # follow the system appearance with Ghostty's built-in Flexoki themes: no
    # theme files to install, they ship with the app.
    package = if isDarwin then null else pkgs.ghostty;
    enableFishIntegration = false;

    settings = {
      # The Nerd Font patch, so box-drawing, powerline segments and the fish
      # prompt's OS logo come out of the primary face with no fallback chain.
      # It has to be the "Mono" cut: its icons are squeezed to one cell, so
      # CoreText reports the family fixed-pitch and ghostty accepts it. The
      # plain "GeistMono Nerd Font" draws them 1.5-2 cells wide, which keeps it
      # out of `ghostty +list-fonts` on the mac entirely, and an unresolvable
      # font-family silently falls back to ghostty's own default.
      #
      # 10 is the size this ran at before MEK Mono; the 15.5 that replaced it
      # only existed to make up MEK's 600/1000em cap height against GeistMono's
      # 710 and its 450 advance against 600.
      font-family = "GeistMono Nerd Font Mono";
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

      background-opacity = 1.0;
      background-blur-radius = 0;

      mouse-hide-while-typing = true;

      window-colorspace = "display-p3";
      confirm-close-surface = false;
      resize-overlay = "never";

      clipboard-read = "allow";
      clipboard-write = "allow";

      # shift+enter helper is cross-platform. The cmd-based global quick-terminal
      # toggle is macOS-only (the `cmd` key doesn't exist on the Linux build).
      keybind = [
        "shift+enter=text:\\x1b\\r"
      ] ++ lib.optionals isDarwin [ "global:cmd+shift+space=toggle_quick_terminal" ];

      # Linux: the single dynamic "Matugen" theme DMS writes (it rewrites the
      # file on every light/dark flip, so one name covers both modes). macOS:
      # follow the system appearance with Ghostty's built-in Flexoki themes
      # (light ↔ dark). The names carry a space, which Ghostty's `light:…,dark:…`
      # theme syntax handles (it only splits on the comma).
      # NOTE (Linux cold start): the Matugen file only exists once DMS has
      # generated a wallpaper palette. Populate ~/Pictures/Wallpapers/{light,dark}
      # or ghostty starts themeless until the first palette is generated.
      theme =
        if isDarwin then
          "light:Flexoki Light,dark:Flexoki Dark"
        else
          "Matugen";
    }
    # macos-titlebar-style is rejected by the Linux build.
    // lib.optionalAttrs isDarwin { macos-titlebar-style = "tabs"; }
    # Ghostty draws a fallback glyph at that face's own advance, so anything
    # wider than the cell bleeds over the ones after it. U+23FA (Claude Code's
    # message bullet) is absent from GeistMono and landed on Noto Emoji at
    # 1270/1000em against the 600 cell: wide enough to cover the trailing space
    # and the first letter of the word after it. Noto Sans Symbols 2 draws the
    # same circle at 910/1000em. Linux only, the Noto fonts aren't on the mac.
    // lib.optionalAttrs (!isDarwin) { font-codepoint-map = "U+23FA=Noto Sans Symbols 2"; };
  };

  # On macOS the ghostty binary is a Homebrew cask, so nixpkgs has no ghostty
  # package and an incoming SSH session (TERM=xterm-ghostty, sent from the Linux
  # box) can't find the terminfo entry, so full-screen apps error with "unknown
  # terminal type". Compile the captured source (./xterm-ghostty.terminfo, from
  # `infocmp -x xterm-ghostty`) into ~/.terminfo using the *system* tic so the
  # output matches Apple's ncurses readers. ~/.terminfo is searched
  # unconditionally. No env var is needed. This is the declarative stand-in
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
