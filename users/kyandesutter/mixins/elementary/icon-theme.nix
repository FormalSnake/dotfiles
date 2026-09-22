# The desktop-wide icon theme: elementary's icons, with the app icons it lacks
# filled from two elementary-style third-party packs, and everything still
# missing resolved through Colloid-Dark, then Adwaita.
#
# elementary ships 28 app icons, so on its own nearly every app falls through
# to the fallback. The packs are copied into the elementary tree (first file
# wins: elementary, expandtheon, urutau) rather than chained with Inherits:
# both declare `Inherits=...,hicolor`, and GTK and Qt walk parents depth first,
# so a chain would reach hicolor's mixed upstream icons before the next pack.
# Only their apps/ folders are taken; urutau is an elementary 5 fork whose
# places and mimes would otherwise show through wherever elementary 8 has a gap.
{ runCommand, fetchFromGitHub, pantheon, imagemagick }:
let
  themeName = "elementary-colloid";

  expandtheon = fetchFromGitHub {
    owner = "ellie-commons";
    repo = "expandtheon";
    rev = "db5b468209fe0212b2baea2a18633607b719d53e";
    hash = "sha256-LOotwKEQgu2BKYEaZ5w8FBqhmM8upzQExCy4jRSgrPw=";
  };

  urutau = fetchFromGitHub {
    owner = "btd1337";
    repo = "urutau-icons";
    rev = "81e97a0aa7a5b0a0b175849d78a5bf063fa4858a";
    hash = "sha256-J/Y21V/rpXjZ+5I7Z0ub4Ij6QF39jvQ1iREHrr168iE=";
  };
in
runCommand "${themeName}-icon-theme" { passthru = { inherit themeName; }; } ''
  theme=$out/share/icons/${themeName}
  mkdir -p $out/share/icons
  cp -r --no-preserve=mode ${pantheon.elementary-icon-theme}/share/icons/elementary $theme

  for pack in ${expandtheon} ${urutau}; do
    for size in 16 24 32 48 64 128 symbolic; do
      [ -d $pack/apps/$size ] || continue
      cp -rnP $pack/apps/$size/. $theme/apps/$size/
    done
  done
  find $theme -xtype l -delete

  # Icons drawn for apps whose own icon clashes with the set (Gemini renders
  # fitted to elementary's 128px keyline, see icons/). 512px masters, named
  # after the desktop entry's Icon=, scaled to every apps size so the theme
  # resolves them before hicolor.
  for src in ${./icons}/*.png; do
    for size in 16 24 32 48 64 128; do
      ${imagemagick}/bin/magick "$src" -resize ''${size}x''${size} "$theme/apps/$size/$(basename "$src")"
    done
  done

  # The upstream cache indexes elementary's files only; without a cache GTK
  # and Qt scan the directories instead.
  rm $theme/icon-theme.cache

  sed -i -e 's/^Name=elementary$/Name=${themeName}/' \
         -e 's/^Inherits=Adwaita$/Inherits=Colloid-Dark,Adwaita,hicolor/' \
         $theme/index.theme
  grep -qx 'Inherits=Colloid-Dark,Adwaita,hicolor' $theme/index.theme
''
