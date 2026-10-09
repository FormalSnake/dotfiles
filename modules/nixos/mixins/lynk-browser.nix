{ pkgs, lib, ... }:
let
  # Lynk Browser (the CEF browser on NativeDesktop) installed from the image
  # `nd package linux` writes. 1Password's browser integration only answers a
  # browser whose binary is root-owned and not writable by the user, so a copy
  # under ~ (AppRun, an extracted AppImage, zig-out) fails with
  # BrowserProcessVerification(BinaryPermissions). From /nix/store it passes.
  #
  # There is no release to fetch: scripts/lynk-browser-update.sh adds a new
  # image to the store and rewrites lynk-browser.json.
  source = lib.importJSON ./lynk-browser.json;

  lynk-browser = pkgs.stdenvNoCC.mkDerivation {
    pname = "lynk-browser";
    inherit (source) version;

    src = pkgs.requireFile {
      inherit (source) name hash;
      message = ''
        ${source.name} is not in the store. Copy the image from `nd package linux`
        to this host and run scripts/lynk-browser-update.sh <image>.
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
      cp -a AppDir $out/opt/lynk-browser
      patchelf --set-interpreter "$(cat ${pkgs.stdenv.cc}/nix-support/dynamic-linker)" \
        $out/opt/lynk-browser/usr/bin/bun
      # GTK's file chooser aborts without its GSettings schemas, and NixOS
      # keeps them out of share/glib-2.0/schemas. These belong to the gtk4
      # nix-ld serves the host. Set inside AppRun so bin/lynk-browser stays a
      # symlink into the AppDir, which scripts resolve to find app/.
      sed -i '/^HERE=/a export XDG_DATA_DIRS="${pkgs.gtk4}/share/gsettings-schemas/${pkgs.gtk4.name}''${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"' \
        $out/opt/lynk-browser/AppRun
      ln -s $out/opt/lynk-browser/AppRun $out/bin/lynk-browser
      sed "s|^Exec=.*|Exec=$out/bin/lynk-browser|" \
        $out/opt/lynk-browser/lynk-browser.desktop > $out/share/applications/lynk-browser.desktop
      if [ -d $out/opt/lynk-browser/usr/share/icons ]; then
        cp -a $out/opt/lynk-browser/usr/share/icons $out/share/icons
      fi
      runHook postInstall
    '';

    meta = {
      description = "Chromium browser on NativeDesktop";
      mainProgram = "lynk-browser";
      platforms = [ "x86_64-linux" ];
    };
  };
in
{
  environment.systemPackages = [ lynk-browser ];

  # 1Password matches the browser process by binary name; the packaged host
  # binary is usr/bin/<slug>.
  environment.etc."1password/custom_allowed_browsers".text = lib.mkAfter "lynk-browser\n";
}
