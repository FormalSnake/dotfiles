{ config, lib, pkgs, ... }:
let
  cfg = config.kyan.desktop;

  # Throwaway Hyprland config for the login greeter. Its only job is to bring up
  # every connected output (so the dGPU-wired external monitor lights up — the
  # old tuigreet was a TTY app stuck on the iGPU's internal panel), run ReGreet,
  # then tear the greeter compositor down so greetd can launch the real session.
  greeterHyprConf = pkgs.writeText "greeter-hyprland.conf" ''
    # Match the session's panel scaling so text isn't tiny on the hidpi internal
    # display; everything else (incl. the external) auto-detects at scale 1.
    monitor = eDP-1, preferred, 0x0, 1.25
    monitor = , preferred, auto, 1

    # No idle/animation noise on the login screen.
    animations { enabled = false }
    cursor { no_hardware_cursors = true }

    # Run the greeter; when it returns (a session was picked) exit the greeter
    # compositor so greetd hands off to the chosen session.
    exec-once = ${lib.getExe config.programs.regreet.package}; hyprctl dispatch exit
  '';
in
{
  options.kyan.desktop.enable = lib.mkEnableOption "Hyprland desktop (system side)";

  config = lib.mkIf cfg.enable {
    programs.hyprland = {
      enable = true;
      withUWSM = true; # session managed by uwsm (clean env / systemd target)
      xwayland.enable = true;
    };

    # xdg portals: hyprland portal + gtk fallback (file pickers, screenshare).
    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    };

    # Graphical login: ReGreet (GTK greeter) running inside a minimal Hyprland
    # instead of tuigreet. tuigreet rendered into the kernel TTY framebuffer,
    # which only exists on the iGPU's internal panel — so the dGPU-wired external
    # monitor stayed blank at login. Running the greeter under a real Wayland
    # compositor wakes the dGPU and drives every output, and ReGreet draws on all
    # connected monitors, so the prompt now appears on the external too.
    programs.regreet = {
      enable = true;
      settings.GTK.application_prefer_dark_theme = true;
    };

    # The regreet module defaults the greetd command to cage (via mkDefault);
    # override it to launch our greeter Hyprland config instead.
    services.greetd = {
      enable = true;
      settings.default_session = {
        command = "${lib.getExe config.programs.hyprland.package} --config ${greeterHyprConf}";
        user = "greeter";
      };
    };

    # polkit agent + secrets/keyring so GUI auth prompts and saved logins work.
    security.polkit.enable = true;
    services.gnome.gnome-keyring.enable = true;

    # UPower: the D-Bus power daemon caelestia reads battery state from. Enable
    # it explicitly — relying on D-Bus auto-activation made battery detection
    # in the caelestia bar flaky.
    services.upower.enable = true;

    # Fonts caelestia/Hyprland expect (Material Symbols, a Nerd Font, emoji).
    # System UI font is Geist; monospace is GeistMono patched with Nerd Font
    # glyphs (terminal/caelestia mono + powerline icons).
    fonts.packages = with pkgs; [
      material-symbols
      geist-font # "Geist" (sans) + "Geist Mono"
      nerd-fonts.geist-mono # "GeistMono Nerd Font"
      noto-fonts
      noto-fonts-color-emoji
    ];

    # Make Geist / GeistMono the default sans/monospace for the whole system
    # (GTK apps, anything resolving the generic sans-serif/monospace families).
    fonts.fontconfig.defaultFonts = {
      sansSerif = [ "Geist" ];
      monospace = [ "GeistMono Nerd Font" ];
    };

    # Backlight permissions: let the `video` group (which kyandesutter is in)
    # write the panel brightness node so `brightnessctl` works without root.
    # brightnessctl ships its own udev rule, but it hardcodes `/bin/chgrp`,
    # which doesn't exist on NixOS — so spell the rule out with store paths.
    # %S%p is the device's sysfs path; the writable attribute is .../brightness.
    services.udev.extraRules = ''
      ACTION=="add", SUBSYSTEM=="backlight", RUN+="${pkgs.coreutils}/bin/chgrp video %S%p/brightness", RUN+="${pkgs.coreutils}/bin/chmod g+w %S%p/brightness"
    '';

    # External-monitor brightness over DDC/CI (ddcutil). Loads the i2c-dev
    # module, creates the `i2c` group and grants it access to /dev/i2c-*.
    # kyandesutter is added to that group in ../mixins/users.nix.
    hardware.i2c.enable = true;

    environment.systemPackages = with pkgs; [
      brightnessctl
      ddcutil # external-monitor brightness (caelestia uses it)
      playerctl
      wl-clipboard
      grim
      slurp
    ];
  };
}
