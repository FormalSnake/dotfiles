{
  # Keep the machine permanently awake and remotely reachable. This is the
  # remote work server, so the guarantees must hold from BOOT, not from login:
  # on 2026-07-23 an unattended reboot parked the mac at the login window with
  # no session — the old launchd *user agent* caffeinate wasn't running, the
  # login window's stock power settings slept the machine within minutes, and
  # wake-on-network was off, leaving it unreachable until a remote FileVault
  # unlock over LAN SSH. Three layers, each sufficient on its own:

  # 1. caffeinate as a root LaunchDaemon: holds the idle-sleep (-i) and on-AC
  #    system-sleep (-s) assertions from boot, no login session required.
  #    KeepAlive respawns it if it ever exits.
  launchd.daemons.caffeinate = {
    serviceConfig = {
      Label = "kyan.caffeinate";
      ProgramArguments = [ "/usr/bin/caffeinate" "-i" "-s" ];
      RunAtLoad = true;
      KeepAlive = true;
    };
  };

  # 2. Firmware-level: never idle-sleep even if caffeinate dies, and come back
  #    unattended after a power cut or kernel freeze.
  power.sleep.computer = "never";
  power.restartAfterPowerFailure = true;
  power.restartAfterFreeze = true;

  # 3. If it sleeps anyway (lid close, manual sleep), answer Wake-on-LAN and
  #    Bonjour wake-on-demand so it can be woken remotely. pmset persists this
  #    across reboots; no dedicated nix-darwin option exists for womp.
  system.activationScripts.postActivation.text = ''
    /usr/bin/pmset -a womp 1
  '';
}
