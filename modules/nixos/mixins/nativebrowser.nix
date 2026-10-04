{ pkgs, lib, ... }:
let
  # NativeBrowser (the CEF browser on NativeDesktop) installed from the image
  # `nd package linux` writes. 1Password's browser integration only answers a
  # browser whose binary is root-owned and not writable by the user, so a copy
  # under ~ (AppRun, an extracted AppImage, zig-out) fails with
  # BrowserProcessVerification(BinaryPermissions). From /nix/store it passes.
  #
  # There is no release to fetch: scripts/nativebrowser-update.sh adds a new
  # image to the store and rewrites nativebrowser.json.
  source = lib.importJSON ./nativebrowser.json;

  nativebrowser = pkgs.stdenvNoCC.mkDerivation {
    pname = "nativebrowser";
    inherit (source) version;

    src = pkgs.requireFile {
      inherit (source) name hash;
      message = ''
        ${source.name} is not in the store. Copy the image from `nd package linux`
        to this host and run scripts/nativebrowser-update.sh <image>.
      '';
    };

    nativeBuildInputs = [
      pkgs.squashfsTools
      pkgs.binutils
      pkgs.patchelf
    ];

    # The packager falls back to a bare squashfs when appimagetool is missing;
    # a real AppImage carries the ELF runtime in front of the same squashfs.
    unpackPhase = ''
      runHook preUnpack
      offset=0
      if [ "$(head -c4 "$src" | od -An -c | tr -d ' ')" = '177ELF' ]; then
        offset=$(LC_ALL=C readelf -h "$src" | awk 'NR==13{o=$5} NR==18{s=$5} NR==19{n=$5} END{print o+s*n}')
      fi
      unsquashfs -q -d AppDir -o "$offset" "$src"
      runHook postUnpack
    '';

    # The host binary and libcef keep the FHS loader and resolve their
    # libraries through nix-ld (mixins/nix-ld.nix). Bun is copied from the
    # packaging host's store, so its loader path is swapped for ours.
    dontStrip = true;
    dontPatchELF = true;
    noAuditTmpdir = true;

    installPhase = ''
      runHook preInstall
      mkdir -p $out/opt $out/bin $out/share/applications
      cp -a AppDir $out/opt/nativebrowser
      patchelf --set-interpreter "$(cat ${pkgs.stdenv.cc}/nix-support/dynamic-linker)" \
        $out/opt/nativebrowser/usr/bin/bun
      ln -s $out/opt/nativebrowser/AppRun $out/bin/nativebrowser
      sed "s|^Exec=.*|Exec=$out/bin/nativebrowser|" \
        $out/opt/nativebrowser/nativebrowser.desktop > $out/share/applications/nativebrowser.desktop
      if [ -d $out/opt/nativebrowser/usr/share/icons ]; then
        cp -a $out/opt/nativebrowser/usr/share/icons $out/share/icons
      fi
      runHook postInstall
    '';

    meta = {
      description = "Chromium browser on NativeDesktop";
      mainProgram = "nativebrowser";
      platforms = [ "x86_64-linux" ];
    };
  };
in
{
  environment.systemPackages = [ nativebrowser ];

  # 1Password matches the browser process by binary name; the packaged host
  # binary is usr/bin/<slug>.
  environment.etc."1password/custom_allowed_browsers".text = lib.mkAfter "nativebrowser\n";
}
