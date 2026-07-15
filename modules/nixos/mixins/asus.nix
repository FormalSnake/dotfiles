{ config, lib, pkgs, ... }:
let
  # Catppuccin Mocha "Mauve" — the accent painted on the Aura keyboard.
  # Deepened from the on-screen value (cba6f7) to compensate for the LEDs: the
  # pastel mauve renders too white on the keyboard, so we drop lightness and
  # bump saturation (HSL 272/89/66) to read as the intended purple.
  auraColour = "b15bf5";

  # Toggle the keyboard backlight brightness node directly (0..max). Used at boot
  # by the asus-aura service to seed an AC-appropriate level without depending on
  # the asusd dbus service being up. (Live AC/battery keyboard following while a
  # session is up is owned by the user session — see power-tune / aura-repaint.)
  #
  # The power-source classifier is the ONE defined in power.nix (published on
  # PATH via /run/current-system) — this file used to carry its own older copy,
  # which had drifted (no charge_mode check, so a USB-C PD charger classified as
  # `ac`). One classifier, one answer.
  kbdDim = pkgs.writeShellScript "asus-kbd-dim" ''
    led=/sys/class/leds/asus::kbd_backlight
    [ -e "$led/brightness" ] || exit 0
    max=$(cat "$led/max_brightness" 2>/dev/null || echo 3)
    case "''${1:-}" in
      on)  echo "$max" > "$led/brightness" ;;
      off) echo 0      > "$led/brightness" ;;
      # ac: classify the source and apply the right level. Used by the asus-aura
      # boot service to re-assert the level *after* it sets the Aura effect (which
      # re-enables the backlight), since at boot there may be no power event yet.
      ac)
        if [ "$(/run/current-system/sw/bin/power-source 2>/dev/null || echo ac)" = ac ]; then echo "$max" > "$led/brightness"; else echo 0 > "$led/brightness"; fi ;;
    esac
  '';
in
{
  options.kyan.asus.enable =
    lib.mkEnableOption "ASUS laptop support (asusd, Aura RGB, battery charge limit)";

  config = lib.mkIf config.kyan.asus.enable {
    # asusd: fan curves, Aura keyboard LEDs, battery charge limit.
    #
    # NOTE: supergfxd is intentionally NOT used for dGPU power management. RTD3 is
    # broken on this Blackwell RTX 5070 + open-module 610 (NVIDIA
    # open-gpu-kernel-modules #882) so the dGPU must be hard-powered-off to save
    # power on battery — but supergfxd applies its Integrated switch only during a
    # logout, and logout black-screens on this machine. Instead, power.nix's
    # dgpu-power does the same hard power-off (unload nvidia → PCI remove →
    # asus-nb-wmi dgpu_disable) *live*, with no logout/reboot, driven by the
    # power-source reconciler. See modules/nixos/mixins/power.nix.
    services.asusd.enable = true;

    # Let the user session drive the keyboard's per-key LEDs via OpenRGB — the
    # aura-ambient screen-sampler (home mixin) needs hidraw access without root
    # and without a system-wide OpenRGB server. asusd still owns the keyboard by
    # default; OpenRGB only takes over on AC. The N-KEY control interface is
    # 0b05:19b6. GROUP+MODE grants access deterministically on any udev trigger —
    # unlike OpenRGB's uaccess rules, which need logind to re-process the device
    # (it's bound at boot before the rules, so a mid-session rebuild never ACLs it,
    # and a background user service can't wait on that timing anyway).
    services.udev.extraRules = ''
      SUBSYSTEM=="hidraw", ATTRS{idVendor}=="0b05", ATTRS{idProduct}=="19b6", MODE="0660", GROUP="users"
    '';

    # After asusd is up: seed the keyboard colour and cap the battery charge at
    # 80% for longevity. The seed is the last wallpaper-derived accent noctalia
    # cached to the user's ~/.cache/noctalia/aura-color (so the keyboard already
    # shows the right colour before the graphical session starts); noctalia
    # repaints it on login anyway. Falls back to the Catppuccin Mauve seed if no
    # cache exists yet. `|| true` so a CLI/permission hiccup never fails the boot.
    systemd.services.asus-aura = {
      description = "Aura keyboard accent seed + 80% charge limit";
      after = [ "asusd.service" ];
      requires = [ "asusd.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        seed="${config.users.users.kyandesutter.home}/.cache/noctalia/aura-color"
        colour="$(${pkgs.coreutils}/bin/cat "$seed" 2>/dev/null || echo ${auraColour})"
        ${pkgs.asusctl}/bin/asusctl aura effect static -c "$colour" || true
        ${pkgs.asusctl}/bin/asusctl battery limit 80 || true
        # Kill the red breathing "slash" pulse the Aura zones run while the
        # laptop is suspended. The power-state flags are all-or-nothing — any
        # flag omitted is set false — so re-assert boot/awake/shutdown and drop
        # --sleep for every zone. Not all zones exist on every chassis; `|| true`.
        for zone in keyboard logo lightbar lid rear-glow; do
          ${pkgs.asusctl}/bin/asusctl aura power "$zone" --boot --awake --shutdown || true
        done
        # Setting the Aura effect above re-enables the backlight, so re-assert the
        # AC-appropriate level last: dark on battery, full on AC. Mirrors the relog
        # fix in users/kyandesutter/mixins/noctalia.nix (aura-repaint).
        ${kbdDim} ac || true
      '';
    };
  };
}
