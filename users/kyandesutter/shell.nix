{ config, pkgs, lib, ... }:
{
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    PAGER = "less";
    LESS = "-FRX";

    # Share portless dev servers on my tailnet by default (equivalent to
    # `portless --tailscale`). Honoured by yarn, bun, npm and direct portless.
    PORTLESS_TAILSCALE = "1";

    JAVA_HOME = "${pkgs.zulu21.home}";
  } // lib.optionalAttrs pkgs.stdenv.isDarwin {
    # macOS-only: the SDK lives under the macOS Library path (wrong on Linux).
    ANDROID_HOME = "${config.home.homeDirectory}/Library/Android/sdk";
  };
}
