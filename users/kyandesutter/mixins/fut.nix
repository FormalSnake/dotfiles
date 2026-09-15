{ lib, pkgs, ... }:
let
  # fut: agent-aware terminal multiplexer (mikker/fut, https://fut.sh). Not in
  # nixpkgs (the `fut` there is the Fusion language). Source needs Rust 1.95
  # plus the vendored libghostty-vt, so we take the release binaries the brew
  # formula ships instead. The linux one is dynamic against glibc, hence the
  # patchelf pass.
  version = "0.19";

  release = {
    x86_64-linux = {
      asset = "fut-linux-x86_64";
      hash = "sha256-WF74aYjOqVI1kAGNBDntCuyyu6J1Lr9sNr8jZVj6Z/c=";
    };
    aarch64-darwin = {
      asset = "fut-macos-arm64";
      hash = "sha256-AexIAv6PMhm/0KJiIG+mI76QhCnsaf9fO1MyWvmQDzc=";
    };
  }.${pkgs.stdenv.hostPlatform.system}
    or (throw "fut: no release binary for ${pkgs.stdenv.hostPlatform.system}");

  fut = pkgs.stdenvNoCC.mkDerivation {
    pname = "fut";
    inherit version;

    src = pkgs.fetchurl {
      url = "https://github.com/mikker/fut/releases/download/${version}/${release.asset}.tar.gz";
      inherit (release) hash;
    };
    # The tarball is the bare binary, no top-level directory.
    sourceRoot = ".";

    nativeBuildInputs = lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.autoPatchelfHook ];
    buildInputs = lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.stdenv.cc.cc.lib ];

    installPhase = ''
      runHook preInstall
      install -Dm755 fut $out/bin/fut
      runHook postInstall
    '';

    meta = {
      description = "Agent-aware terminal multiplexer";
      homepage = "https://fut.sh";
      mainProgram = "fut";
      platforms = [ "x86_64-linux" "aarch64-darwin" ];
    };
  };
in
{
  home.packages = [ fut ];
}
