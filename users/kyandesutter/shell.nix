{ pkgs, ... }:
{
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    PAGER = "less";
    LESS = "-FRX";

    JAVA_HOME = "${pkgs.zulu21.home}";
    ANDROID_HOME = "/Users/kyandesutter/Library/Android/sdk";
  };
}
