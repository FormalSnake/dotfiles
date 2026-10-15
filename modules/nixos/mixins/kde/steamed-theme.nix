# The 2003 Steam / GoldSrc VGUI look: colour scheme, Plasma style, Aurorae
# window decoration and the bitmap Tahoma, as one global theme ("Steamed").
{ stdenvNoCC, fetchFromGitHub }:
stdenvNoCC.mkDerivation {
  pname = "steamed-kde-theme";
  version = "0-unstable-2026-01-24";
  src = fetchFromGitHub {
    owner = "UNATCO-JCDenton";
    repo = "Steamed";
    rev = "14e8a1c0db188870ab3ac2059dbf941fad9c3065";
    hash = "sha256-DonoMblcHEZ0oYdWdq78HeZTctf/O7pT6TU7Ce+7osM=";
  };
  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/fonts/truetype
    cp -r color-schemes aurorae plasma $out/share/
    cp fonts/WineTahomaBit.ttf $out/share/fonts/truetype/
    runHook postInstall
  '';
}
