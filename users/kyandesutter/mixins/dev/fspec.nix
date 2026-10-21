{ inputs, pkgs, ... }:
let
  fspec = inputs.formalspec.packages.${pkgs.stdenv.hostPlatform.system}.fspec;
in
{
  home.packages = [ fspec ];

  # The output of `fspec dev direnv`. A file in direnv/lib rather than
  # programs.direnv.stdlib, which direnv-apple-toolchain.nix already owns.
  xdg.configFile."direnv/lib/fspec.sh".text = ''
    # FormalSpec project environments: `use fspec` in an .envrc next to dev.star.
    use_fspec() {
      watch_file dev.star fspec.lock
      local out
      out=$(fspec dev export --dir "$PWD") || return 1
      eval "$out"
    }
  '';
}
