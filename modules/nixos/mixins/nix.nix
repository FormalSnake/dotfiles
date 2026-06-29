{ inputs, ... }:
{
  # nixpkgs.config.allowUnfree + the pi-coding-agent overlay live in ../../shared.
  # This module adds the NixOS-only Nix daemon settings (the macbook uses
  # Determinate Nix, which owns those there).

  # Heroic Games Launcher (gaming profile) pulls pnpm in at *build time* only
  # (heroic-unwrapped's nativeBuildInputs); the updated nixpkgs flags
  # pnpm-10.29.2 insecure. It is not in the runtime closure, so permit the
  # build-time use. Bump/remove once heroic's nixpkgs node moves to a newer pnpm.
  nixpkgs.config.permittedInsecurePackages = [ "pnpm-10.29.2" ];

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    # chaotic (CachyOS kernel / scx) binary cache so we don't compile kernels.
    substituters = [ "https://nyx-cache.chaotic.cx/" ];
    trusted-public-keys = [
      "nyx-cache.chaotic.cx:dJxTrgMC3V3cFfyIiBQDQorG6k1LsqurH/srpMSq7qk="
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
