{ pkgs, ... }:
{
  # ananicy-cpp + the CachyOS rule set — the remaining piece of CachyOS-Settings
  # parity (see mixins/boot.nix for the sysctl/udev half). Auto-applies
  # nice/ionice/latency-nice from curated per-process rules: builds, compilers
  # and indexers get demoted, interactive apps protected, so background load
  # stops competing with the foreground. Coexists with scx (CachyOS ships both).
  services.ananicy = {
    enable = true;
    package = pkgs.ananicy-cpp;
    rulesProvider = pkgs.ananicy-rules-cachyos;
  };
}
