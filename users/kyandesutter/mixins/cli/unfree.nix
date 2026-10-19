{ ... }:
{
  # nixpkgs.config.allowUnfree in modules/shared/mixins/nix.nix only covers the
  # pkgs the system and home-manager build from. Ad-hoc CLI calls evaluate their
  # own nixpkgs, so allow unfree there too, by all three routes nixpkgs checks:

  # 1. The legacy path (nix-shell, nix-build, nix-env, import <nixpkgs>).
  xdg.configFile."nixpkgs/config.nix".text = ''
    { allowUnfree = true; }
  '';

  # 2. check-meta reads this when config.allowUnfree is unset.
  home.sessionVariables.NIXPKGS_ALLOW_UNFREE = "1";

  # 3. Flake commands evaluate purely, where builtins.getEnv returns "" and the
  # variable above is invisible, so `nix run nixpkgs#<unfree>` fails with no way
  # to configure it. --impure is the only lever; scope it to bare nixpkgs# refs
  # so project flakes keep pure eval.
  programs.fish.functions.nix = {
    wraps = "nix";
    description = "nix, with unfree allowed for ad-hoc nixpkgs# refs";
    body = ''
      if contains -- "$argv[1]" run shell build develop eval
          and string match -q '*nixpkgs#*' -- $argv
          and not contains -- --impure $argv
          command nix $argv[1] --impure $argv[2..]
      else
          command nix $argv
      end
    '';
  };
}
