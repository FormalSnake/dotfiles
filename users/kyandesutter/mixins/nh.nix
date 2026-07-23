{ config, ... }:
{
  # nh — nix helper: `nh os switch` wraps rebuilds with a nom build log and an
  # nvd diff of what changed between generations. Cross-platform (nh 4 speaks
  # darwin-rebuild too). NH_FLAKE points it at this repo so a bare `nh os
  # switch` works from anywhere.
  programs.nh = {
    enable = true;
    flake = "${config.home.homeDirectory}/.config/nix";
  };
}
