# Kvantum's KvMojaveLight recoloured onto matugen roles (see
# kvantum-recolor.py), as a pair of matugen templates rather than a finished
# theme: Kvantum paints from literals in an SVG, so the palette can only reach
# it by rendering the SVG again. One template serves both modes and both Qt
# majors, which read the same ~/.config/Kvantum.
{ runCommand, python3, kdePackages }:
let
  src = "${kdePackages.qtstyleplugin-kvantum}/share/Kvantum/KvMojaveLight";
in
runCommand "elementary-matugen-kvantum-templates"
  {
    nativeBuildInputs = [ python3 ];
    passthru.themeName = "ElementaryMatugen";
  }
  ''
    mkdir -p $out
    python3 ${./kvantum-recolor.py} \
      ${src}/KvMojaveLight.svg ${src}/KvMojaveLight.kvconfig \
      $out/theme.svg.tmpl $out/theme.kvconfig.tmpl
  ''
