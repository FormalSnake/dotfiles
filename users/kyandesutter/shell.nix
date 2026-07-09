{ pkgs, ... }:
{
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    PAGER = "less";
    LESS = "-FRX";

    # Share portless dev servers on my tailnet by default (equivalent to
    # `portless --tailscale`). Honoured by yarn, bun, npm and direct portless.
    PORTLESS_TAILSCALE = "1";

    # The JDK gradle (Android) and other JVM tooling run under. ANDROID_HOME and
    # the SDK's PATH entries live in ./mixins/android.nix.
    JAVA_HOME = "${pkgs.zulu21.home}";
  };
}
