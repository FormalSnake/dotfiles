{ pkgs, ... }:
{
  # Bambu Studio — the slicer for Bambu Lab 3D printers (unfree; allowUnfree is
  # global in modules/shared/mixins/nix.nix). Linux-only: nixpkgs has no
  # aarch64-darwin build, so it's imported from linux.nix rather than the
  # cross-platform base.
  #
  # It's unfree, so Hydra never builds it and there's no binary cache — it always
  # compiles from source here. Cap ninja to -j6: the default -j$NIX_BUILD_CORES
  # (24 on the g815) runs 24 heavy C++ translation units at once, each 1-2 GB,
  # which blows past the 30 GB of RAM, thrashes swap, and OOM-kills the whole
  # rebuild. The ninja hook appends ninjaFlags after its own -j, so this wins.
  home.packages = [
    (pkgs.bambu-studio.overrideAttrs (old: {
      ninjaFlags = (old.ninjaFlags or [ ]) ++ [ "-j6" ];
    }))
  ];
}
