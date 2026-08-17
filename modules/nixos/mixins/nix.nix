{ config, inputs, ... }:
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

  # Owner policy (2026-08-17): keep only the last 3 system generations, the
  # same window the limine boot menu shows. nix-collect-garbage can only
  # delete generations by age (the old --delete-older-than 2d let 14 same-day
  # generations pile up, and would conversely reap 2 of the kept 3 whenever
  # the config sat stable for a few days), so trim the profile to the last 3
  # first and let the plain collection pass reap whatever that unpinned.
  systemd.services.nix-gc.preStart = ''
    ${config.nix.package}/bin/nix-env --delete-generations +3 -p /nix/var/nix/profiles/system
  '';
  nix.gc = {
    automatic = true;
    dates = "daily";
  };

  # `sudo nixos-rebuild` evaluates as root, so the private flake inputs
  # (CanaryOrchestrator, FormalShell) are fetched over SSH by root — which has
  # an empty ~/.ssh and no way to answer a host-key prompt, so the fetch died
  # with "Host key verification failed" and took the whole rebuild with it.
  # System-wide known_hosts fixes it for every user, root included. The mac is
  # unaffected: darwin-rebuild evaluates as the invoking user.
  programs.ssh.knownHosts.github = {
    hostNames = [
      "github.com"
      "ssh.github.com"
    ];
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
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
