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
    # connected/enabled/dpms On. No compositor IPC command recovers it (tested via hyprctl at the time);
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

  # Automatic output routing by priority — device-specific (headphone MACs, this
  # chassis's PCI audio addresses), so it lives here rather than in the generic
  # audio mixin. WirePlumber always switches the default sink to the
  # highest-priority *available* node, and auto-falls back when it disappears.
  # Order: CMF Headphone Pro / AirPods > HDMI > built-in speakers. A manual pick
  # (DMS / `wpctl set-default` / pavucontrol) is stored as a "configured
  # default" and overrides this until you change it again.
  services.pipewire.wireplumber.extraConfig."51-output-priorities" = {
    # CMF Headphone Pro (bluetooth, MAC 2C:BE:EE:65:A0:21) — highest priority.
    "monitor.bluez.rules" = [
      {
        matches = [ { "node.name" = "~bluez_output.2C_BE_EE_65_A0_21.*"; } ];
        actions.update-props = {
          "priority.session" = 2000;
          "priority.driver" = 2000;
        };
      }

      # AirPods Pro (bluetooth, MAC 14:14:7D:E7:8C:E3). They otherwise connect
      # with `bluez5.profile = "off"`, so no sink/source node is ever created
      # and they don't appear as an audio device. Pin the initial profile to
      # A2DP (high-fidelity AAC playback) and auto-connect that profile so the
      # sink always shows up. Trade-off: A2DP has no microphone — switch the
      # card to `headset-head-unit` (via DMS/wpctl) when you need the mic.
      {
        matches = [ { "device.name" = "bluez_card.14_14_7D_E7_8C_E3"; } ];
        actions.update-props = {
          "device.profile" = "a2dp-sink";
          "bluez5.auto-connect" = [ "a2dp_sink" ];
        };
      }

      # …and make the AirPods a preferred default output when present.
      {
        matches = [ { "node.name" = "~bluez_output.14_14_7D_E7_8C_E3.*"; } ];
        actions.update-props = {
          "priority.session" = 2000;
          "priority.driver" = 2000;
        };
      }
    ];

    # HDMI (GPU audio @ 02:00.1) above built-in analog speakers (@ 00:1f.3).
    "monitor.alsa.rules" = [
      {
        matches = [ { "node.name" = "~alsa_output.pci-0000_02_00.1.*"; } ];
        actions.update-props = {
          "priority.session" = 1500;
          "priority.driver" = 1500;
        };
      }
      {
        matches = [ { "node.name" = "~alsa_output.pci-0000_80_1f.3.*"; } ];
        actions.update-props = {
          "priority.session" = 1000;
          "priority.driver" = 1000;
        };
      }
    ];
  };

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

  # ASUS laptop support: asusd, Aura keyboard RGB (Flexoki blue), 80%
  # battery charge limit, dim-LEDs-on-battery.
  kyan.asus.enable = true;

  # Sober — Roblox client for Linux (Flatpak-only, managed declaratively).
  kyan.sober.enable = true;

  # AirPlay screen-mirroring receiver (UxPlay). Run `uxplay -p` to show an
  # iPhone's screen in a window; share that window in meetings.
  kyan.airplay.enable = true;

  home-manager.users.kyandesutter = {
    imports = [
      self.homeModules.kyandesutter
      self.homeModules.kyandesutter-linux
    ];
  };

  # Set once at install and never change (matches the macbook's pattern).
  system.stateVersion = "25.11";
}
