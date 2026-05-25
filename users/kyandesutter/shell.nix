{ pkgs, ... }:
{
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    PAGER = "less";
    LESS = "-FRX";

    JAVA_HOME = "${pkgs.zulu17.home}";
    ANDROID_HOME = "/Users/kyandesutter/Library/Android/sdk";
  };
}
