{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.kyan.desktop.enable {
    # TuneD as the power-profile backend, in place of power-profiles-daemon
    # (2026-08-17). tuned-ppd owns both `net.hadess.PowerProfiles` and
    # `org.freedesktop.UPower.PowerProfiles`, so `powerprofilesctl`, the shell's
    # profile switcher and every gdbus watcher in this repo keep talking to the
    # same API. Only the backend changes: PPD wrote the EPP hint and the
    # firmware platform profile and stopped there, while a TuneD profile also
    # carries governor, disk, SATA link-power, audio and sysctl settings, and
    # ships a separate on-battery variant. That split is the point — the AC
    # profile can be aggressive without the battery paying for it.
    #
    # The nixpkgs module disables power-profiles-daemon itself and asserts
    # against tlp/auto-cpufreq/system76-power, so no host has to. It also needs
    # upower (mixins/hyprland.nix already enables it) and polkit.
    #
    # Defaults are left alone deliberately: they already are Fedora's mapping —
    # power-saver→powersave, balanced→balanced, performance→
    # throughput-performance, plus balanced→balanced-battery once upower reports
    # discharging. TuneD's `balanced` writes platform_profile itself (its
    # `[acpi]` section), so asus-wmi stays driven exactly as PPD drove it.
    #
    # Who picks the active profile is unchanged: power-reconcile on the g815
    # (mixins/power.nix), the shell's battery popout everywhere else.
    services.tuned.enable = true;

    # nixos-hardware's common-pc-laptop enables TLP whenever
    # power-profiles-daemon is off, which is now always. Turning PPD off is how
    # we got here, so say no to its replacement directly (its mkDefault yields
    # to this) or TuneD's conflict assertion fires.
    services.tlp.enable = false;

    # `tuned-adm` arrives with the daemon, but powerprofilesctl left PATH along
    # with the PPD service that used to put it there. Keep the client — it's the
    # muscle memory, and it drives tuned-ppd exactly as it drove PPD.
    environment.systemPackages = [ pkgs.power-profiles-daemon ];

    # tuned-ppd mirrors /sys/firmware/acpi/platform_profile back into its own
    # active profile — upstream's Fn-key integration, written for ThinkPads.
    # On asus-wmi that closes a loop which pins the profile permanently: the
    # node reads quiet/balanced/performance, tuned-ppd's table only knows
    # low-power/balanced/performance, and since the 6.14 multi-driver binding
    # the legacy node is write-only through /sys/class/platform-profile, so
    # TuneD's own `[acpi]` writes come back EOPNOTSUPP and never move it. Every
    # `powerprofilesctl set` was reverted ~25 ms later (measured on the g815,
    # 2026-08-17). asusd owns the platform profile on both laptops, so stop
    # tuned-ppd watching it. Not expressible via `services.tuned.ppdSettings`:
    # the module's `main` submodule declares only default/battery_detection and
    # takes no freeform keys.
    environment.etc."tuned/ppd.conf".source = lib.mkForce (
      (pkgs.formats.ini { }).generate "ppd.conf" (
        lib.recursiveUpdate config.services.tuned.ppdSettings { main.sysfs_acpi_monitor = false; }
      )
    );
  };
}
