{ pkgs, ... }:
let
  # Plymouth only scales with interpolation, so the pixel-art logo (32 px,
  # shown at 2x on the blog) and the Geist Pixel wordmark (rendered on the
  # font's own 26 px grid) are point-scaled here for each integer scale the
  # script can pick.
  formalos = pkgs.runCommand "plymouth-theme-formalos" { nativeBuildInputs = [ pkgs.imagemagick ]; } ''
    dir=$out/share/plymouth/themes/formalos
    mkdir -p $dir
    for s in 1 2 3 4; do
      magick ${./logo.png} -filter point -resize $((200 * s))% $dir/logo-$s.png
      magick ${./wordmark.png} -filter point -resize $((100 * s))% $dir/wordmark-$s.png
    done
    magick -size 1x1 xc:'#2a2927' $dir/track.png
    magick -size 1x1 xc:'#879a39' $dir/fill.png
    cp ${./formalos.script} $dir/formalos.script
    cat > $dir/formalos.plymouth <<EOF
    [Plymouth Theme]
    Name=FormalOS
    Description=The FormalOS boot splash from the blog
    ModuleName=script

    [script]
    ImageDir=$dir
    ScriptFile=$dir/formalos.script
    EOF
  '';
in
{
  # Boot splash between Limine and the greeter. No nvidia modules in the
  # initrd: plymouth draws on simpledrm and hands the framebuffer over when
  # the driver loads.
  boot.plymouth = {
    enable = true;
    theme = "formalos";
    themePackages = [ formalos ];
  };

  # systemd stage 1. The scripted initrd only starts the splash after
  # switch-root; with systemd in the initrd plymouth comes up as the first
  # unit and stays up through the root mount and the switch.
  boot.initrd.systemd.enable = true;
  boot.initrd.verbose = false;

  # Keep kernel and udev chatter off the splash. Log level 3 still surfaces
  # errors; "quiet" also makes systemd default show_status to auto.
  boot.consoleLogLevel = 3;
  boot.kernelParams = [
    "quiet"
    "udev.log_level=3"
  ];
}
