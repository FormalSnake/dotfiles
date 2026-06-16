{ inputs, self, ... }:
{
  imports = [
    # Generated on first boot with `nixos-generate-config` — placeholder for now.
    ./hardware-configuration.nix

    # nixos-hardware: no profile exists for the G815 chassis, so compose generics.
    inputs.nixos-hardware.nixosModules.common-cpu-intel
    inputs.nixos-hardware.nixosModules.common-pc-laptop
    inputs.nixos-hardware.nixosModules.common-pc-laptop-ssd
    # common-gpu-nvidia == PRIME offload (despite the bare name).
    inputs.nixos-hardware.nixosModules.common-gpu-nvidia

    # NOTE: this laptop's Wi-Fi is an Intel BE200 (iwlwifi/iwlmld), NOT a
    # MediaTek MT7925. The old MT7925 nixos-hardware import was a no-op against
    # a driver that never loads, so it was removed; see the Wi-Fi block below.
  ];

  nixpkgs.hostPlatform = "x86_64-linux";

  networking.hostName = "g815";

  # Intel Core Ultra 9 275HX (Arrow Lake-HX).
  hardware.cpu.intel.updateMicrocode = true;

  # Intel BE200 (Wi-Fi 7) latency fix. The iwlmld driver defaults to the
  # "balanced" power scheme (=2), which lets the radio sleep between packets;
  # the AP then buffers and delivers them in bursts, producing big latency
  # spikes and intermittent loss even on a strong 5GHz link (observed: 4ms min
  # vs 86ms avg / 175ms max RTT to the gateway). power_scheme=1 forces
  # Continuously Active Mode for low, consistent latency.
  boot.extraModprobeConfig = ''
    options iwlwifi power_save=0
    options iwlmld power_scheme=1
  '';

  # Set the Wi-Fi regulatory domain (was 00/world, which caps TX power and
  # available channels). Spain (Canary Islands).
  boot.kernelParams = [ "cfg80211.ieee80211_regdom=ES" ];

  # Belt-and-suspenders: keep NetworkManager from re-enabling Wi-Fi powersave.
  networking.networkmanager.wifi.powersave = false;

  # PRIME offload bus IDs — verified on the real hardware via `lspci -D`:
  #   0000:00:02.0 Intel Arrow Lake-S iGPU → PCI:0:2:0
  #   0000:02:00.0 NVIDIA GB206M (RTX 5070 Mobile, Blackwell) → PCI:2:0:0
  hardware.nvidia.prime = {
    intelBusId = "PCI:0:2:0";
    nvidiaBusId = "PCI:2:0:0";
  };

  # Profiles (enable the desktop + gaming stacks for this host).
  kyan.profiles.desktop.enable = true;
  kyan.profiles.gaming.enable = true;

  # ASUS laptop support: asusd, Aura keyboard RGB (Catppuccin Mauve), 80%
  # battery charge limit, dim-LEDs-on-battery.
  kyan.asus.enable = true;

  # Sober — Roblox client for Linux (Flatpak-only, managed declaratively).
  kyan.sober.enable = true;

  home-manager.users.kyandesutter = {
    imports = [
      self.homeModules.kyandesutter
      self.homeModules.kyandesutter-linux
    ];
  };

  # Set once at install and never change (matches the macbook's pattern).
  system.stateVersion = "25.11";
}
