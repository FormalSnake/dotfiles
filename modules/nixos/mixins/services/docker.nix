{ config, lib, ... }:
let
  cfg = config.kyan.docker;
in
{
  options.kyan.docker.enable = lib.mkEnableOption "Docker engine for the Linux dev host";

  config = lib.mkIf cfg.enable {
    virtualisation.docker = {
      enable = true;
      # Nothing here runs as a service; the daemon starts on the first docker
      # call and stays out of the boot path otherwise.
      enableOnBoot = false;
    };
    users.users.kyandesutter.extraGroups = [ "docker" ];
  };
}
