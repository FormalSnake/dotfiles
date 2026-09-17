# elementary's stylesheet recoloured onto matugen roles (see recolor.py), as a
# light and a dark GTK theme. Two themes rather than one with gtk-dark.css:
# FormalShell flips org.gnome.desktop.interface gtk-theme between a light and a
# dark name on every mode change, the same way it drives adw-gtk3.
{ runCommand, python3, pantheon }:
let
  src = "${pantheon.elementary-gtk-theme}/share/themes/io.elementary.stylesheet.blueberry";
in
runCommand "elementary-matugen-gtk-theme"
  {
    nativeBuildInputs = [ python3 ];
    passthru.themeName = mode: "elementary-matugen-${mode}";
  }
  ''
    for mode in light dark; do
      for gtk in gtk-3.0 gtk-4.0; do
        dir=$out/share/themes/elementary-matugen-$mode/$gtk
        mkdir -p $dir
        cp -r ${src}/$gtk/assets $dir/
        python3 ${./recolor.py} dark ${src}/$gtk/gtk-dark.css $dir/gtk-dark.css
      done
    done

    for gtk in gtk-3.0 gtk-4.0; do
      python3 ${./recolor.py} light ${src}/$gtk/gtk.css $out/share/themes/elementary-matugen-light/$gtk/gtk.css
    done

    for mode in light dark; do
      for f in gtk.css gtk-dark.css; do
        [ -f $out/share/themes/elementary-matugen-$mode/gtk-4.0/$f ] || continue
        cat ${./libadwaita.css} >> $out/share/themes/elementary-matugen-$mode/gtk-4.0/$f
      done
    done

    for gtk in gtk-3.0 gtk-4.0; do
      cp $out/share/themes/elementary-matugen-dark/$gtk/gtk-dark.css $out/share/themes/elementary-matugen-dark/$gtk/gtk.css
    done
  ''
