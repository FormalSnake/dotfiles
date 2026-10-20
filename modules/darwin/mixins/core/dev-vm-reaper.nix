{ config, ... }:
let
  home = config.users.users.kyandesutter.home;
  flakeDir = "${home}/.config/nix";
in
{
  # Stops qemu dev VMs (FormalShell's testvm and linux-builder) after two hours
  # without a connection. The script lives in the repo, same as storage-gc.nix,
  # so the cutoff can be tuned without a rebuild.
  launchd.user.agents.kyan-dev-vm-reaper = {
    serviceConfig = {
      Label = "kyan.dev-vm-reaper";
      ProgramArguments = [
        "/bin/bash"
        "${flakeDir}/scripts/dev-vm-reaper.sh"
      ];
      EnvironmentVariables = {
        PATH = "/usr/bin:/bin:/usr/sbin:/sbin";
        HOME = home;
      };
      StartInterval = 900;
      RunAtLoad = true;
      StandardOutPath = "${home}/Library/Logs/kyan-dev-vm-reaper.log";
      StandardErrorPath = "${home}/Library/Logs/kyan-dev-vm-reaper.log";
    };
  };
}
