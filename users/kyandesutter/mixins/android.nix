{ config, ... }:
let
  # Android Studio (homebrew cask in systems/macbook/homebrew.nix) owns the SDK
  # and installs it here — this mixin only wires up the env the CLI toolchain
  # (gradle, Expo/React Native, adb) needs to find it. macOS-only: the Library
  # path is wrong on Linux, so this is imported from ../darwin.nix.
  sdk = "${config.home.homeDirectory}/Library/Android/sdk";
in
{
  # ANDROID_HOME is the variable Google's tooling reads; ANDROID_SDK_ROOT is
  # deprecated. Gradle falls back to it when a project has no local.properties.
  # JAVA_HOME (zulu21, the JDK gradle runs under) is set in ../shell.nix.
  home.sessionVariables.ANDROID_HOME = sdk;

  # sessionPath rather than fish_add_path: fish_add_path writes a *universal*
  # variable, so the entries persist as imperative state in fish_variables and
  # survive removal from this config. home-manager instead renders these into
  # hm-session-vars.fish, which every fish session sources.
  home.sessionPath = [
    "${sdk}/platform-tools" # adb, fastboot
    "${sdk}/emulator" # emulator
    "${sdk}/cmdline-tools/latest/bin" # sdkmanager, avdmanager
  ];
}
