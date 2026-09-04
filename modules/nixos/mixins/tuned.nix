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
    # ships a separate on-battery variant. That split is the point: the AC
    # profile can be aggressive without the battery paying for it.
    #
    # The nixpkgs module disables power-profiles-daemon itself and asserts
    # against tlp/auto-cpufreq/system76-power, so no host has to. It also needs
    # upower (mixins/hyprland.nix already enables it) and polkit.
    #
    # Defaults are left alone deliberately: they already are Fedora's mapping:
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
    # with the PPD service that used to put it there. Keep the client: it's the
    # muscle memory, and it drives tuned-ppd exactly as it drove PPD.
    #
    # The binary only. The full package also ships the D-Bus activation files
    # for net.hadess.PowerProfiles and org.freedesktop.UPower.PowerProfiles,
    # and both name `SystemdService=power-profiles-daemon.service` — a unit
    # that no longer exists here, since enabling TuneD is what turns PPD off.
    # TuneD ships its own copies of those two files pointing at
    # tuned-ppd.service, but the system path merges with ignoreCollisions, so
    # whichever package sorts first wins and PPD's dead pair had been winning.
    # Anything that reaches for the power-profile API before tuned-ppd owns
    # the name then fails to activate it: quickshell asks at shell start, and
    # on a failed activation it gives up for the life of the process, so the
    # shell's profile buttons silently do nothing until it restarts. That is
    # a coin flip on every `nixos-rebuild switch`, which restarts the shell
    # and tuned-ppd with no ordering between them (caught on the e1504g
    # 2026-09-04: shell up at 11:30:00, tuned-ppd at 11:30:04, buttons dead
    # for two days).
    environment.systemPackages = [
      (pkgs.runCommandLocal "powerprofilesctl" { } ''
        mkdir -p $out/bin
        ln -s ${lib.getExe' pkgs.power-profiles-daemon "powerprofilesctl"} $out/bin/powerprofilesctl
      '')
    ];

    # tuned-ppd mirrors /sys/firmware/acpi/platform_profile back into its own
    # active profile: upstream's Fn-key integration, written for ThinkPads.
    # Here it races the profile it just applied: switching to power-saver makes
    # TuneD's `[acpi]` plugin write the node, the inotify handler reads it back
    # before asus-wmi has settled, sees the outgoing value and reverts. Measured
    # on the g815 (2026-08-17): every `powerprofilesctl set` undone ~35 ms later,
    # so the profile never left whatever asusd had parked there. The mapping is
    # no use on this hardware anyway: asus-wmi's low tier is called `quiet`,
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
    # up: without this a config change lands in /etc and does nothing until the
    # next boot.
    systemd.services.tuned-ppd.restartTriggers = [
      config.environment.etc."tuned/ppd.conf".source
    ];

    # Don't let `performance` outlive a boot. tuned-ppd persists the selected
    # profile to /etc/tuned/ppd_base_profile and, at startup, that file beats
    # ppd.conf's `default` outright: controller.initialize() resolves
    # `_load_base_profile() or _get_recommend_profile() or default_profile`
    # (tuned 2.27.0, tuned/ppd/controller.py:388). So one "let me try
    # performance" from the shell's battery popout pinned the e1504g to the
    # loud tier on every subsequent boot, with nothing in the UI saying why
    # (found 2026-09-01: governor and platform_profile both `performance`,
    # RAPL back at the firmware 15/35 W, defeating the quiet-fans caps in
    # systems/e1504g/default.nix).
    #
    # Clear only that one value. balanced and power-saver still persist across
    # reboots, so a deliberate quieter choice sticks; performance falls back to
    # this host's declared default. On the g815 the default IS performance
    # (always on the barrel charger), so there the reset is a no-op and the
    # host keeps booting flat out.
    systemd.services.tuned-ppd.serviceConfig.ExecStartPre = [
      "${pkgs.writeShellScript "tuned-ppd-unpin-performance" ''
        state=/etc/tuned/ppd_base_profile
        default=${lib.escapeShellArg config.services.tuned.ppdSettings.main.default}
        if [ -e "$state" ] && [ "$(cat "$state")" = performance ] && [ "$default" != performance ]; then
          printf '%s\n' "$default" > "$state"
        fi
      ''}"
    ];
  };
}
