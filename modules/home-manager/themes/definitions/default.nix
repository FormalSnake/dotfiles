{pkgs, ...}: {
  catppuccin = import ./catppuccin.nix {inherit pkgs;};
  everforest = import ./everforest.nix {inherit pkgs;};
  nord = import ./nord.nix {inherit pkgs;};
}