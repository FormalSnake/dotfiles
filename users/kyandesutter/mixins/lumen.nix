{ pkgs, ... }:
let
  # lumen — AI git commit-message generator (jnsahaj/lumen). Referenced by the
  # gcommit/gpush/commitai fish helpers and the LUMEN_* env in mixins/fish.nix.
  # Not in nixpkgs and upstream ships darwin-only release binaries, so on the
  # macbook it comes from the homebrew tap (systems/macbook/homebrew.nix) and on
  # NixOS we build it from source here. git2 vendors libgit2 + openssl, hence the
  # cmake/pkg-config/perl native inputs.
  lumen = pkgs.rustPlatform.buildRustPackage rec {
    pname = "lumen";
    version = "2.30.0";

    src = pkgs.fetchFromGitHub {
      owner = "jnsahaj";
      repo = "lumen";
      tag = "v${version}";
      hash = "sha256-EoxMYlWHmuprjjhvj3GyCxGDIcT/d+JMda9j75pqs+k=";
    };

    cargoHash = "sha256-qTFRfy+Wutee5SbaMaqcYjXgr6xZKYYBIuyVA7jAGiY=";

    nativeBuildInputs = with pkgs; [
      cmake
      pkg-config
      perl
    ];

    # Network-dependent integration tests; skip in the sandbox.
    doCheck = false;
  };
in
{
  home.packages = [ lumen ];
}
