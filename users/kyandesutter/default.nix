{
  imports = [
    ./programs.nix
    ./shell.nix
    ./mixins/fish.nix
    ./mixins/git.nix
    ./mixins/gh.nix
    ./mixins/ssh.nix
  ];

  home = {
    username = "kyandesutter";
    homeDirectory = "/Users/kyandesutter";
    stateVersion = "26.05";
  };

  programs.home-manager.enable = true;
}
