{ inputs, ... }:
{
  # nixpkgs.config.allowUnfree + the pi-coding-agent overlay live in ../../shared.
  # This module adds the NixOS-only Nix daemon settings (the macbook uses
  # Determinate Nix, which owns those there).

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    # chaotic (CachyOS kernel / scx) binary cache so we don't compile kernels;
    # claude-code cache so the claude-code-nix input never builds locally;
    # kopuz cache so the music player never builds locally either.
    substituters = [
      "https://nyx-cache.chaotic.cx/"
      "https://claude-code.cachix.org"
      "https://kopuz.cachix.org"
    ];
    trusted-public-keys = [
      "nyx-cache.chaotic.cx:dJxTrgMC3V3cFfyIiBQDQorG6k1LsqurH/srpMSq7qk="
      "claude-code.cachix.org-1:YeXf2aNu7UTX8Vwrze0za1WEDS+4DuI2kVeWEE4fsRk="
      "kopuz.cachix.org-1:J2X3AnAYhKTJW5S3aCLoA1ckonQXVNZMQvhZA0YAufw="
    ];
    trusted-users = [
      "root"
      "@wheel"
    ];
    auto-optimise-store = true;
  };

  nix.gc = {
    automatic = true;
    dates = "daily";
    options = "--delete-older-than 2d";
  };

  # Helium browser overlay (pkgs.helium). Set at the system level so it is also
  # visible to home-manager (useGlobalPkgs = true).
  nixpkgs.overlays = [
    inputs.helium.overlays.default

    # nixpkgs removed the `buildFHSEnvChroot` alias (it now `throw`s — added
    # upstream 2026-05-21), but the pinned nordvpn-flake (already at its latest
    # commit) still calls `pkgs.buildFHSEnvChroot` to wrap the NordVPN .deb.
    # Restore the alias to `buildFHSEnv` — exactly the migration the deprecation
    # message recommends. Remove once nordvpn-flake migrates to buildFHSEnv.
    (final: prev: {
      buildFHSEnvChroot = prev.buildFHSEnv;
    })
  ];
}
