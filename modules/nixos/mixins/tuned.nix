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
    # Here it races the profile it just applied: switching to power-saver makes
    # TuneD's `[acpi]` plugin write the node, the inotify handler reads it back
    # before asus-wmi has settled, sees the outgoing value and reverts. Measured
    # on the g815 (2026-08-17): every `powerprofilesctl set` undone ~35 ms later,
    # so the profile never left whatever asusd had parked there. The mapping is
    # no use on this hardware anyway — asus-wmi's low tier is called `quiet`,
    # which the table doesn't carry. Turn the mirror off; asusd owns the
    # platform profile, and TuneD still writes it on every switch.
    #
    # Not expressible via `services.tuned.ppdSettings`: the module's `main`
    # submodule declares only default/battery_detection and takes no freeform
    # keys.
    environment.etc."tuned/ppd.conf".source = lib.mkForce (
      (pkgs.formats.ini { }).generate "ppd.conf" (
        lib.recursiveUpdate config.services.tuned.ppdSettings { main.sysfs_acpi_monitor = false; }
      )
    );

    # ppd.conf is read once at startup, and the nixpkgs module doesn't wire it
    # up — without this a config change lands in /etc and does nothing until the
    # next boot.
    systemd.services.tuned-ppd.restartTriggers = [
      config.environment.etc."tuned/ppd.conf".source
    ];
  };
}
