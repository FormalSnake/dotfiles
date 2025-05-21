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
}

