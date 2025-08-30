{
  config,
  pkgs,
  inputs,
  ...
}: let
  spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.system};
in {
  programs.spicetify = {
    enable = false;
    theme = spicePkgs.themes.catppuccin;
    colorScheme = "mocha";
    # enabledExtensions = with spicePkgs.extensions; [
    #   beautifulLyrics
    # ];
  };
}
