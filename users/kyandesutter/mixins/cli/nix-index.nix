{ inputs, ... }:
{
  # nix-index + comma: `, cowsay` runs any program from nixpkgs ad hoc. The
  # nix-index-database module ships a prebuilt weekly database, so neither
  # comma nor the fish command-not-found handler needs a local `nix-index` run.
  imports = [ inputs.nix-index-database.homeModules.nix-index ];

  programs.nix-index.enable = true;
  programs.nix-index-database.comma.enable = true;
}
