{ inputs, ... }:
{
  # FormalMusic (github:FormalSnake/formalmusic), the NativeDesktop YouTube Music
  # client on Kopuz's daemon. kopuzd and the Kopuz app (mixins/apps/kopuz.nix) own
  # the same library and only one runs at a time, so no kopuzd service: the window
  # attaches to whichever is up and starts kopuzd itself when nothing answers.
  # Matugen owns ~/.config/formalmusic/theme.json (mixins/desktop/dms.nix), so
  # `theme` stays empty.
  imports = [ inputs.formalmusic.homeModules.default ];

  programs.formalmusic = {
    enable = true;
    daemon = false;
  };
}
