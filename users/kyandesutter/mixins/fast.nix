{ pkgs, ... }:
let
  # fast — command-line internet speed test powered by fast.com
  # (maaslalani/fast). Not in nixpkgs and upstream ships no release tags, so we
  # build it from source pinned to a commit. Bubbletea/lipgloss TUI.
  fast = pkgs.buildGoModule {
    pname = "fast";
    version = "0-unstable-2026-01-01";

    src = pkgs.fetchFromGitHub {
      owner = "maaslalani";
      repo = "fast";
      rev = "26d8fc9c189ba748c68f8930af11dee5c2467f7e";
      hash = "sha256-YeDx082+ySqzamo9UutFTXXkrb37nmqt3ZUNzUHShf4=";
    };

    vendorHash = "sha256-YSjJ8NOL97hXZLnfGYIjoKmARv+gWOsv+5qkl9konnA=";
  };
in
{
  home.packages = [ fast ];
}
