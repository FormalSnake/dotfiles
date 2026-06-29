# clipssh — paste local clipboard images into agents running over SSH.
#
# Runs on the machine you're sitting at (the one with the clipboard): grabs a
# PNG from the clipboard, scp's it to the remote, and copies the remote path
# back to your clipboard so you paste it into Claude Code / opencode / etc.,
# which auto-attaches the image.
#
#   clipssh user@host                 # one-off
#   clipssh alias add box user@host   # save a host
#   clipssh box                       # use the alias
#
# Upstream is a plain bash script; we just pin it and wrap the clipboard tools
# onto its PATH (pngpaste/pbcopy on darwin, wl-clipboard/xclip on linux).
{ pkgs, lib, ... }:
let
  clipssh = pkgs.stdenvNoCC.mkDerivation {
    pname = "clipssh";
    version = "0-unstable-2026-06-15";

    src = pkgs.fetchFromGitHub {
      owner = "samuellawrentz";
      repo = "clipssh";
      rev = "c7f4e8ddcf102302c6375ba51534c7505ddc2616";
      hash = "sha256-HkSVap02E/Y6fhg6PYnnMbF8KOVh9XYf8WXXrf/pTZE=";
    };

    nativeBuildInputs = [ pkgs.makeWrapper ];
    dontBuild = true;

    installPhase = ''
      runHook preInstall
      install -Dm755 clipssh "$out/bin/clipssh"
      wrapProgram "$out/bin/clipssh" \
        --prefix PATH : ${lib.makeBinPath (
          [ pkgs.openssh pkgs.coreutils pkgs.gnugrep ]
          ++ lib.optionals pkgs.stdenv.isDarwin [ pkgs.pngpaste ]
          ++ lib.optionals pkgs.stdenv.isLinux [ pkgs.wl-clipboard pkgs.xclip ]
        )}
      runHook postInstall
    '';

    meta = {
      description = "Paste local clipboard images into terminal tools over SSH";
      homepage = "https://github.com/samuellawrentz/clipssh";
      license = lib.licenses.mit;
      mainProgram = "clipssh";
      platforms = lib.platforms.unix;
    };
  };
in
{
  home.packages = [ clipssh ];
}
