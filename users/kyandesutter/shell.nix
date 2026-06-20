{ pkgs, lib, ... }:
{
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    PAGER = "less";
    LESS = "-FRX";

    JAVA_HOME = "${pkgs.zulu21.home}";
  } // lib.optionalAttrs pkgs.stdenv.isDarwin {
    # macOS-only: the SDK lives under the macOS Library path (wrong on Linux).
    ANDROID_HOME = "/Users/kyandesutter/Library/Android/sdk";
  };
}
