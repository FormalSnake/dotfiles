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
  boot.kernelParams = [
    "cfg80211.ieee80211_regdom=ES"

    # Internal eDP-1 panel (i915) goes "lit but black" after a long idle on
    # this hybrid laptop. The BOE NE180QDM panel is scanned out by the iGPU
    # while its backlight is driven by nvidia_wmi_ec_backlight (stays at 100% →
    # "lit"). The actual failure is at modeset: the kernel logs
    #   i915 0000:00:02.0: [drm] PHY A failed to request refclk
    # on every attempt to bring the panel back — the eDP PHY can't get its
    # reference clock, so no image, even though the connector reports
    # connected/enabled/dpms On. No compositor (hyprctl) command recovers it;
    # only a full GPU re-init (reboot / suspend-resume) does. The cause is i915
    # display power management gating the PHY refclk over idle:
    #   • enable_dc=0  — keep the display power wells up (don't enter DC5/DC6),
    #                    which is what gates the refclk; primary fix.
    #   • enable_psr=0 — disable Panel Self Refresh (same failure family).
    # Cost is a little idle power on the iGPU; no other behavioural change.
    "i915.enable_dc=0"
    "i915.enable_psr=0"

    # Disable CPU speculative-execution mitigations for a CPU-bound performance
    # win (~5-15% on some workloads; smaller on Arrow Lake-HX, which is newer
    # silicon needing fewer of them). SECURITY TRADE-OFF: drops Spectre/Meltdown
    # -class protections. Acceptable here — a single-user personal gaming laptop,
    # not a shared/server host running untrusted code.
    "mitigations=off"
  ];

  # Belt-and-suspenders: keep NetworkManager from re-enabling Wi-Fi powersave.
  networking.networkmanager.wifi.powersave = false;

  # PRIME offload bus IDs — verified on the real hardware via `lspci -D`:
  #   0000:00:02.0 Intel Arrow Lake-S iGPU → PCI:0:2:0
  #   0000:02:00.0 NVIDIA GB206M (RTX 5070 Mobile, Blackwell) → PCI:2:0:0
  hardware.nvidia.prime = {
    intelBusId = "PCI:0:2:0";
    nvidiaBusId = "PCI:2:0:0";
  };

  # External USB SSD holding the Steam library (ext4, label "Steam").
  # Declared here so it mounts at boot instead of relying on the desktop
  # session's udisks auto-mount — otherwise Steam starts before the disk is
  # mounted and drops the library, forcing a manual re-add every boot.
  # `nofail` keeps boot from hanging when the drive is unplugged; `x-systemd`
  # options make it an automount that activates on first access and gives up
  # if the device never shows.
  fileSystems."/mnt/steam" = {
    device = "/dev/disk/by-uuid/1f80aa17-b86f-4d9c-94e5-b1f7898c583f";
    fsType = "ext4";
    options = [
      "nofail"
      "x-systemd.automount"
      "x-systemd.device-timeout=10s"
    ];
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
