{ config, lib, pkgs, ... }:
let
  cfg = config.kyan.android;
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
  # Android Studio owns the SDK and installs it at its platform default. On the
  # mac the IDE is the homebrew cask (systems/macbook/homebrew.nix); on Linux
  # it comes from nixpkgs below. This mixin wires the env the CLI toolchain
  # (gradle, Expo/React Native, adb) needs to find the SDK.
  sdk =
    if isDarwin then
      "${config.home.homeDirectory}/Library/Android/sdk"
    else
      "${config.home.homeDirectory}/Android/Sdk";
in
{
  options.kyan.android.enable = lib.mkEnableOption "Android SDK env, JAVA_HOME for gradle, and Android Studio on Linux";

  config = lib.mkIf cfg.enable {
    home.packages = lib.optionals (!isDarwin) [ pkgs.android-studio ];

    home.sessionVariables = {
      # ANDROID_HOME is the variable Google's tooling reads; ANDROID_SDK_ROOT is
      # deprecated. Gradle falls back to it when a project has no local.properties.
      ANDROID_HOME = sdk;
      # zulu21 itself is on PATH everywhere through programs.nix.
      JAVA_HOME = "${pkgs.zulu21.home}";
    };

    # sessionPath rather than fish_add_path: fish_add_path writes a *universal*
    # variable, so the entries persist as imperative state in fish_variables and
    # survive removal from this config. Home-manager instead renders these into
    # hm-session-vars.fish, which every fish session sources.
    home.sessionPath = [
      "${sdk}/platform-tools" # adb, fastboot
      "${sdk}/emulator" # emulator
      "${sdk}/cmdline-tools/latest/bin" # sdkmanager, avdmanager
    ];
  };
}
