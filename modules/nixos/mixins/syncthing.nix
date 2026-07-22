{ config, lib, ... }:
let
  cfg = config.kyan.syncthing;
  home = config.users.users.kyandesutter.home;

  # Device IDs are the runtime-generated Syncthing identities (keys live in
  # ~/.config/syncthing on the laptops, ~/Library/Application Support/Syncthing
  # on the mac). A reinstalled machine gets a new ID that must be updated here.
  # Addresses: tailscale IP first, home-LAN lease second (same fallback
  # reasoning as the e1504g remote builder in systems/e1504g/default.nix).
  devices = {
    g815 = {
      id = "RZNUFVO-2QUBLVO-DHGP2EB-V333ZXG-SVAML24-WUPSJO6-NTAAR3H-Y65UMAH";
      addresses = [
        "tcp://100.114.32.78:22000"
        "tcp://192.168.86.95:22000"
      ];
    };
    e1504g = {
      id = "HYLBO36-NKACQGL-2TE7JU2-SPQ2HY3-NGIUYFA-A7DLSMT-YF3UCRQ-ITAA3AL";
      addresses = [
        "tcp://100.109.196.64:22000"
        "tcp://192.168.86.116:22000"
      ];
    };
    macbook = {
      id = "CQLDKS4-HHYBPSK-SBVNP7N-OALAOEQ-V76L267-6HVCDXU-POMKKF2-TZGDYQX";
      addresses = [ "tcp://100.75.60.102:22000" ];
    };
  };
  peers = lib.attrNames devices;
in
{
  options.kyan.syncthing.enable = lib.mkEnableOption "Syncthing mesh (wallpapers + zen profile) with the macbook as the always-on hub";

  config = lib.mkIf cfg.enable {
    services.syncthing = {
      enable = true;
      user = "kyandesutter";
      group = "users";
      dataDir = home;
      configDir = "${home}/.config/syncthing";
      overrideDevices = true;
      overrideFolders = true;
      settings = {
        options = {
          urAccepted = -1;
          # Addresses are pinned above; the tailnet reaches everywhere a
          # relay or discovery server would.
          globalAnnounceEnabled = false;
          localAnnounceEnabled = false;
          relaysEnabled = false;
          natEnabled = false;
        };
        inherit devices;
        folders = {
          wallpapers = {
            id = "wallpapers";
            path = "${home}/Pictures/Wallpapers";
            devices = peers;
          };
          # Live Zen profile. One browser at a time; .stignore (rendered by
          # mixins/zen.nix) excludes locks, crash state and 1Password.
          zen-profile = {
            id = "zen-profile";
            path = "${home}/.config/zen/default";
            devices = peers;
          };
        };
      };
    };

    # LAN fallback path; tailscale0 is already a trusted interface
    # (mixins/phone-integration.nix), so only the LAN needs the port.
    networking.firewall.allowedTCPPorts = [ 22000 ];
    networking.firewall.allowedUDPPorts = [ 22000 ];
  };
}
