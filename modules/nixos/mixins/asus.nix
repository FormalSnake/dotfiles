{ config, lib, pkgs, ... }:
let
  # Flexoki blue: the accent painted on the Aura keyboard. Uses the deeper,
  # more saturated blue-600 stop (#205EA6 vs the on-screen blue-400 #4385BE) so
  # it reads as blue on the washed-out keyboard LEDs rather than white.
  auraColour = "205ea6";
in
{
  options.kyan.asus.enable =
    lib.mkEnableOption "ASUS laptop support (asusd, Aura RGB, battery charge limit)";

  config = lib.mkIf config.kyan.asus.enable {
    # asusd: fan curves, Aura keyboard LEDs, battery charge limit. The GPU MUX
    # is written straight to asus-nb-wmi (systems/g815/default.nix); supergfxd
    # is not installed.
    services.asusd.enable = true;

    # After asusd is up: seed the keyboard colour and cap the battery charge at
    # 80% for longevity (the machine lives on the charger). The seed is the
    # last wallpaper-derived accent the matugen aura template cached to the
    # user's ~/.cache/dank/aura-color (so the keyboard already shows the right
    # colour before the graphical session starts); the session repaints it on
    # login anyway. Falls back to the Flexoki blue seed if no cache exists
    # yet. `|| true` so a CLI/permission hiccup never fails the boot.
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
        seed="${config.users.users.kyandesutter.home}/.cache/dank/aura-color"
        colour="$(${pkgs.coreutils}/bin/cat "$seed" 2>/dev/null || echo ${auraColour})"
        ${pkgs.asusctl}/bin/asusctl aura effect static -c "$colour" || true
        ${pkgs.asusctl}/bin/asusctl battery limit 80 || true
        # Kill the red breathing "slash" pulse the Aura zones run while the
        # laptop is suspended. The power-state flags are all-or-nothing: any
        # flag omitted is set false. So re-assert boot/awake/shutdown and drop
        # --sleep for every zone. Not all zones exist on every chassis: `|| true`.
        for zone in keyboard logo lightbar lid rear-glow; do
          ${pkgs.asusctl}/bin/asusctl aura power "$zone" --boot --awake --shutdown || true
        done
      '';
    };
  };
}
