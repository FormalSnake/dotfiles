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
      # Agents build and test in containers all day, and on the g815's 256 GB
      # root unused images and build cache filled the disk to 0 bytes free
      # (2026-10-21). Volumes are left alone: they can hold data.
      autoPrune = {
        enable = true;
        dates = "daily";
        flags = [ "--all" "--filter" "until=72h" ];
      };
    };
    users.users.kyandesutter.extraGroups = [ "docker" ];
  };
}
