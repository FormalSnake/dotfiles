{ lib, pkgs, ... }:
let
  # terminal-browser (zenbu-labs): chromium rendered into the terminal over
  # the kitty graphics protocol. Not in nixpkgs; the macbook takes the brew
  # cask (systems/macbook/homebrew.nix), the Linux hosts the release tarball,
  # which bundles its own electron build (`electron/pixel`) plus the cli and
  # browser bundles it runs through ELECTRON_RUN_AS_NODE. The library list
  # and the vulkan-loader swap mirror nixpkgs' electron-bin.
  version = "0.11.1";

  release = {
    x86_64-linux = {
      asset = "terminal-browser-linux-x64";
      hash = "sha256-sIMnZVqjGQJgzzSAcpS+fHxmhaomOaOTBVt8ZJ7rOko=";
    };
  }.${pkgs.stdenv.hostPlatform.system}
    or (throw "terminal-browser: no release binary for ${pkgs.stdenv.hostPlatform.system}");

  terminal-browser = pkgs.stdenv.mkDerivation {
    pname = "terminal-browser";
    inherit version;

    src = pkgs.fetchurl {
      url = "https://github.com/zenbu-labs/terminal-browser/releases/download/v${version}/${release.asset}.tar.gz";
      inherit (release) hash;
    };

    nativeBuildInputs = [ pkgs.autoPatchelfHook ];
    buildInputs = with pkgs; [
      alsa-lib
      at-spi2-atk
      cairo
      cups
      dbus
      expat
      gdk-pixbuf
      glib
      gtk3
      gtk4
      nss
      nspr
      libx11
      libxcb
      libxcomposite
      libxdamage
      libxext
      libxfixes
      libxrandr
      libxkbfile
      pango
      pciutils
      stdenv.cc.cc.lib
      systemd
      libnotify
      pipewire
      libsecret
      libpulseaudio
      speechd-minimal
      libdrm
      libgbm
      libxkbcommon
      libxshmfence
      libGL
      vulkan-loader
    ];

    installPhase = ''
      runHook preInstall
      mkdir -p $out/lib $out/bin
      cp -r . $out/lib/terminal-browser
      chmod u-x $out/lib/terminal-browser/electron/*.so*
      # The system loader finds the driver ICDs; the bundled one does not.
      ln -sf ${lib.getLib pkgs.vulkan-loader}/lib/libvulkan.so.1 $out/lib/terminal-browser/electron/libvulkan.so.1
      # The launcher resolves the symlink and locates its tree from there.
      ln -s $out/lib/terminal-browser/bin/terminal-browser $out/bin/terminal-browser
      runHook postInstall
    '';

    meta = {
      description = "Chromium in the terminal";
      homepage = "https://github.com/zenbu-labs/terminal-browser";
      mainProgram = "terminal-browser";
      platforms = [ "x86_64-linux" ];
    };
  };
in
{
  home.packages = [ terminal-browser ];
}
