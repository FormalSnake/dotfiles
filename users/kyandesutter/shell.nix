{ pkgs, ... }:
{
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    PAGER = "less";
    LESS = "-FRX";

    # CocoaPods (Ruby 3.4) aborts at startup without a UTF-8 locale.
    LANG = "en_US.UTF-8";

    # Share portless dev servers on my tailnet by default (equivalent to
    # `portless --tailscale`). Honoured by yarn, bun, npm and direct portless.
    PORTLESS_TAILSCALE = "1";

    # The JDK gradle (Android) and other JVM tooling run under. ANDROID_HOME and
    # the SDK's PATH entries live in ./mixins/android.nix.
    JAVA_HOME = "${pkgs.zulu21.home}";
  };
}
