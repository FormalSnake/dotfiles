{ pkgs, ... }:
{
  home.packages = [
    pkgs.just
  ];

  programs = {
    man.generateCaches = false;

    bat.enable = true;
    btop.enable = true;
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
    eza = {
      enable = true;
      icons = "auto";
    };
    fd.enable = true;
    fzf.enable = true;
    ripgrep.enable = true;
    zoxide.enable = true;
  };
}
