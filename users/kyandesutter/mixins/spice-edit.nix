{ pkgs, lib, ... }:
let
  # spice-edit — mouse-first terminal code editor for SSH/tmux workflows
  # (spice-edit.com). Not in nixpkgs; single static Go binary.
  spice-edit = pkgs.buildGoModule rec {
    pname = "spice-edit";
    version = "0.0.41";

    src = pkgs.fetchFromGitHub {
      owner = "cloudmanic";
      repo = "spice-edit";
      rev = "v${version}";
      hash = "sha256-PdsvS11tHMeYXbPD6kM6210p7aKWYJrRhhE6DJBLoJg=";
    };

    vendorHash = "sha256-rjmk+9Yz3riXfvCERs6noGuVOFyEt8SoHbxjAt7D2IY=";

    env.CGO_ENABLED = 0;
    ldflags = [ "-s" "-w" ];

    # module path is spice-edit but upstream ships the binary as spiceedit
    postInstall = ''
      mv $out/bin/spice-edit $out/bin/spiceedit
    '';

    meta = {
      description = "Mouse-first terminal code editor for SSH workflows";
      homepage = "https://spice-edit.com";
      license = lib.licenses.mit;
      mainProgram = "spiceedit";
    };
  };
in
{
  home.packages = [ spice-edit ];
}
