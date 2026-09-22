{ lib, pkgs, ... }:
let
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
in
{
  programs.ghostty = {
    enable = true;
    # nixpkgs has no darwin build, so there the binary is the `ghostty`
    # Homebrew cask and this only writes ~/.config/ghostty/config. Linux takes
    # the nixpkgs package.
    #
    # Theming differs per platform (see `theme` below). On Linux the colours
    # are wallpaper-derived: matugen renders the palette into
    # ~/.config/ghostty/themes/Matugen and SIGUSR2-reloads ghostty (the
    # `ghostty` template in mixins/dms.nix). On macOS Ghostty's built-in
    # Flexoki themes follow the system appearance.
    package = if isDarwin then null else pkgs.ghostty;
    enableFishIntegration = false;

    settings = {
      # The Nerd Font patch, so box-drawing, powerline segments and the fish
      # prompt's OS logo come out of the primary face with no fallback chain.
      #
      # Two cuts, one per platform. Linux takes the plain family, where the
      # icons keep their drawn 1.5-2 cell width. CoreText won't report that
      # family as fixed-pitch, so on the mac it never appears in `ghostty
      # +list-fonts` and an unresolvable font-family falls back to ghostty's own
      # default without saying so; the "Mono" cut squeezes the icons to one cell
      # and is accepted there.
      font-family = if isDarwin then "GeistMono Nerd Font Mono" else "GeistMono Nerd Font";
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
      window-decoration = "auto";
      confirm-close-surface = false;
      resize-overlay = "never";

      clipboard-read = "allow";
      clipboard-write = "allow";

      # The cmd-based global quick-terminal toggle is macOS-only (the `cmd`
      # key doesn't exist on the Linux build).
      keybind = [
        "shift+enter=text:\\x1b\\r"
      ] ++ lib.optionals isDarwin [ "global:cmd+shift+space=toggle_quick_terminal" ];

      # Linux: the single dynamic "Matugen" theme (rewritten on every
      # light/dark flip, so one name covers both modes). macOS: the built-in
      # Flexoki pair. The names carry a space, which the `light:…,dark:…`
      # syntax handles (it only splits on the comma).
      # Linux cold start: the Matugen file only exists once a wallpaper
      # palette has been rendered; ghostty starts themeless until then.
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
  # `infocmp -x xterm-ghostty`) into ~/.terminfo using the system tic so the
  # output matches Apple's ncurses readers. ~/.terminfo is searched
  # unconditionally, no env var needed. This is the declarative stand-in for
  # ghostty's `ssh-terminfo` shell-integration feature, disabled above.
  home.activation.ghosttyTerminfo = lib.mkIf isDarwin (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ -x /usr/bin/tic ]; then
        run /usr/bin/tic -x -o "$HOME/.terminfo" ${./xterm-ghostty.terminfo} || true
      fi
    ''
  );
}
