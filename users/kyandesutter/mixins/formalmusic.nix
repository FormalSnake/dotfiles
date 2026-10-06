{ inputs, ... }:
{
  # FormalMusic (github:FormalSnake/formalmusic), the GPUI YouTube Music client.
  # The module installs the app with its desktop entry and icon and runs
  # formalmusicd as a user service, so playback and MPRIS survive closing the
  # window. Matugen owns ~/.config/formalmusic/theme.json (mixins/dms.nix), so
  # `theme` stays empty.
  imports = [ inputs.formalmusic.homeModules.default ];

  programs.formalmusic.enable = true;
}
