{ lib, pkgs, ... }:
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
    }
    // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
      # nixpkgs git sets credential.helper=osxkeychain in its own gitconfig, and
      # that helper is ad-hoc signed: every git bump is a new binary to the
      # keychain ACL, so the next read pops an "allow" dialog that hangs any
      # agent shell. Apple's copy is anchor-apple signed and stays trusted.
      # GitHub never reaches this (gh.nix routes it to gh auth git-credential).
      credential.helper = [
        ""
        "/Library/Developer/CommandLineTools/usr/libexec/git-core/git-credential-osxkeychain"
      ];
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
