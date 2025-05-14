{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: {
  # Configure home directory and username specific to this host
  home.username = "kyandesutter";
  home.homeDirectory = "/Users/kyandesutter";
  
  # Host-specific packages
  home.packages = with pkgs; [
    repomix
    nodejs
    bun
    cargo
    rustc
    devenv
    go
    zig
    nixd
    lua
    chafa
  ];
  
  # Host-specific settings
  programs.oh-my-posh = {
    useTheme = "huvix";
  };
  
  # Host-specific homebrew packages
  # These will be merged with the ones from modules/darwin/homebrew.nix
  homebrew = {
    casks = [
      "notion"
      "ghostty"
      "clop"
      "figma"
      "claude"
      "zerotier-one"
      "balenaetcher"
      "slack"
      "jordanbaird-ice"
      "betterdisplay"
      "steam"
      "loop"
      "latest"
      "spotify"
    ];
    brews = [
      "jnsahaj/lumen/lumen"
      "lazydocker"
      "couchdb"
    ];
  };
}