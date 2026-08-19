{ pkgs, ... }:
{
  # ananicy-cpp + the CachyOS rule set: the remaining piece of CachyOS-Settings
  # parity (see mixins/boot.nix for the sysctl/udev half). Auto-applies
  # nice/ionice/latency-nice from curated per-process rules: builds, compilers
  # and indexers get demoted, interactive apps protected, so background load
  # stops competing with the foreground. Coexists with scx (CachyOS ships both).
  services.ananicy = {
    enable = true;
    # glibc 2.42 exposed a missing <cstring> include in ananicy-cpp. The fix
    # (nixpkgs#552211, same upstream MR patch as below) merged 2026-08-16,
    # minutes after the pinned nixos-unstable cut. Drop the override once
    # plain pkgs.ananicy-cpp builds again.
    package = pkgs.ananicy-cpp.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [
        (pkgs.fetchpatch {
          name = "fix-cstring-include.patch";
          url = "https://gitlab.com/ananicy-cpp/ananicy-cpp/-/merge_requests/43.diff";
          hash = "sha256-drBUVh+N3KedJttzQIIA1s+38ngK9BgZFOdpxqBWV0E=";
        })
      ];
    });
    rulesProvider = pkgs.ananicy-rules-cachyos;
  };
}
