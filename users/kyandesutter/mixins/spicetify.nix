{ config, pkgs, inputs, ... }:
let
  spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in
{
  # Spotify wrapped by spicetify with the Catppuccin theme, colour scheme
  # following the global catppuccin.flavor (mocha → mocha, latte → latte, …).
  # The module installs spotify itself — do NOT add pkgs.spotify anywhere or the
  # two installs collide. spicetify-nix builds the unfree spotify internally, so
  # this works regardless of the global allowUnfree setting.
  imports = [ inputs.spicetify-nix.homeManagerModules.spicetify ];

  programs.spicetify = {
    enable = true;
    theme = spicePkgs.themes.catppuccin;
    colorScheme = config.catppuccin.flavor;
  };
}
