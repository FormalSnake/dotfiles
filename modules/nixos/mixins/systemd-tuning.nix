{ lib, ... }:
{
  # Bound how long systemd waits for a unit to stop before SIGKILLing it.
  # The default is 90s, so any single service that fails to stop cleanly
  # makes a reboot hang on the "A stop job is running for ... (1min 30s)"
  # spinner. This box reboots constantly for Windows dual-boot, so cap the
  # worst case at 10s for both the system manager and per-user managers.
  systemd.settings.Manager.DefaultTimeoutStopSec = lib.mkDefault "10s";
  systemd.user.settings.Manager.DefaultTimeoutStopSec = lib.mkDefault "10s";
}
