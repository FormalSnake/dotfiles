{ lib, ... }:
{
  programs.git = {
    enable = true;
    lfs.enable = true;

    settings = {
      user = {
        name = "FormalSnake";
        email = "kyaniserni@gmail.com";
      };
      core.precomposeUnicode = true;
      init.defaultBranch = "main";
      http.postBuffer = 157286400;
      pull.rebase = false;
    };

    # Override home-manager's lfs.enable which writes absolute nix-store
    # paths into the filter config. GitHub Desktop expects the canonical
    # `git-lfs ...` form (it warns otherwise).
    iniContent.filter.lfs = {
      clean = lib.mkForce "git-lfs clean -- %f";
      smudge = lib.mkForce "git-lfs smudge -- %f";
      process = lib.mkForce "git-lfs filter-process";
      required = lib.mkForce true;
    };
  };
}
