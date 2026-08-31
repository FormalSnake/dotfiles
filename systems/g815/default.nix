{ inputs, self, ... }:
{
  imports = [
    # Generated on first boot with `nixos-generate-config` (placeholder for now).
    ./hardware-configuration.nix

    # Windows 11 dual-boot (chainload entry, reboot-to-windows one-shot).
    ./windows-dualboot.nix

    # nixos-hardware: no profile exists for the G815 chassis, so compose generics.
    inputs.nixos-hardware.nixosModules.common-cpu-intel
    inputs.nixos-hardware.nixosModules.common-pc-laptop
    inputs.nixos-hardware.nixosModules.common-pc-laptop-ssd

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

    # Disable CPU speculative-execution mitigations for a CPU-bound performance
    # win (~5-15% on some workloads; smaller on Arrow Lake-HX, which is newer
    # silicon needing fewer of them). SECURITY TRADE-OFF: drops Spectre/Meltdown
    # -class protections. Acceptable here: a single-user personal laptop,
    # not a shared/server host running untrusted code.
    "mitigations=off"
  ];

  # Belt-and-suspenders: keep NetworkManager from re-enabling Wi-Fi powersave.
  networking.networkmanager.wifi.powersave = false;

  # systemd-resolved, this host only for now (the e1504g follows once it has run
  # here for a while). The point is per-link DNS with routing domains: tailscaled
  # registers `~tailb24294.ts.net` against tailscale0 over resolved's D-Bus API
  # instead of taking /etc/resolv.conf hostage. Without it tailscaled wins that
  # fight outright (resolv.conf lists 100.100.100.100 and nothing else, so every
  # lookup in the system goes through MagicDNS) right up until NordVPN connects
  # and overwrites the file.
  #
  # The resolved module sets networking.networkmanager.dns = "systemd-resolved"
  # and turns resolvconf off itself, so this line is the whole change. The
  # /etc/hosts pin in modules/nixos/mixins/networking.nix stays: nordvpnd writes
  # /etc/resolv.conf directly and knows nothing about resolved, so a connected
  # NordVPN still shadows MagicDNS the same way it does today.
  services.resolved.enable = true;

  # Automatic output routing by priority (device-specific: headphone MACs, this
  # chassis's PCI audio addresses), so it lives here rather than in the generic
  # audio mixin. WirePlumber always switches the default sink to the
  # highest-priority *available* node, and auto-falls back when it disappears.
  # Order: CMF Headphone Pro / AirPods > HDMI > built-in speakers. A manual pick
  # (DMS / `wpctl set-default` / pavucontrol) is stored as a "configured
  # default" and overrides this until you change it again.
  services.pipewire.wireplumber.extraConfig."51-output-priorities" = {
    # CMF Headphone Pro (bluetooth, MAC 2C:BE:EE:65:A0:21): highest priority.
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
      # sink always shows up. Trade-off: A2DP has no microphone; switch the
      # card to `headset-head-unit` (via DMS/wpctl) when you need the mic.
      {
        matches = [ { "device.name" = "bluez_card.14_14_7D_E7_8C_E3"; } ];
        actions.update-props = {
          "device.profile" = "a2dp-sink";
          "bluez5.auto-connect" = [ "a2dp_sink" ];
        };
      }

      # And make the AirPods a preferred default output when present.
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

  # GPU MUX: route the internal panel through the dGPU (Armoury Crate's
  # "Ultimate" mode) so the desktop renders and scans out on the RTX 5070 for
  # both outputs instead of blitting HDMI frames across from the iGPU.
  # gpu_mux_mode is the asus-wmi
  # knob supergfxd would write: 0 = dGPU, 1 = Optimus. The firmware keeps the
  # value and a change only takes effect at the next boot, so this only writes
  # when the mode is wrong. Windows shares the setting and boots in dGPU mode
  # as well. The kernel refuses the write while dgpu_disable=1; nothing here
  # sets that any more.
  systemd.services.gpu-mux-dgpu = {
    description = "Route the internal panel through the dGPU (ASUS MUX)";
    after = [ "asusd.service" ];
    wantedBy = [ "multi-user.target" ];
    unitConfig.ConditionPathExists = "/sys/devices/platform/asus-nb-wmi/gpu_mux_mode";
    serviceConfig.Type = "oneshot";
    script = ''
      knob=/sys/devices/platform/asus-nb-wmi/gpu_mux_mode
      [ "$(cat "$knob")" = 0 ] && exit 0
      echo 0 > "$knob"
      echo "MUX switched to dGPU, takes effect at the next boot"
    '';
  };

  # Always on the barrel charger: start tuned-ppd in performance and never
  # let it swap to the battery variant.
  services.tuned.ppdSettings.main = {
    default = "performance";
    battery_detection = false;
  };

  # Profiles (enable the desktop stack for this host).
  kyan.profiles.desktop.enable = true;

  # FormalShell owns the session here too, promoted off the e1504g trial. Same
  # deal as there: DMS stays installed but dormant, rollback is deleting this
  # line. The GOA/EDS calendar still needs its one-time
  # `XDG_CURRENT_DESKTOP=GNOME gnome-control-center online-accounts` sign-in per
  # machine, and SDDM stays the greeter.
  kyan.desktop.shell = "formalshell";

  # NVIDIA dGPU stack. This chassis has the RTX 5070; an Intel-only host
  # leaves this off.
  kyan.nvidia.enable = true;

  # Bare Steam client, workshop downloads only (gaming lives on Windows,
  # see mixins/steam.nix).
  kyan.steam.enable = true;

  # Modrinth App. The instance directory is the Windows one, symlinked by
  # link-minecraft-to-windows (./windows-dualboot.nix), so both OSes launch the
  # same mods, config and worlds instead of two copies that drift.
  kyan.minecraft.enable = true;

  # Roblox via Sober (mixins/roblox.nix). Android-runtime client, needs
  # Vulkan, so it stays on the dGPU host rather than the shared desktop
  # profile.
  kyan.roblox.enable = true;

  # ASUS laptop support: asusd, Aura keyboard RGB (Flexoki blue), 80%
  # battery charge limit.
  kyan.asus.enable = true;

  # AirPlay screen-mirroring receiver (UxPlay). Run `uxplay -p` to show an
  # iPhone's screen in a window, share that window in meetings.
  kyan.airplay.enable = true;

  # NordVPN (privacy/geo exit). This host holds the account login.
  kyan.nordvpn.enable = true;

  # Syncthing mesh: wallpapers + Helium profile, macbook as hub
  # (modules/nixos/mixins/syncthing.nix; spec 2026-07-22).
  kyan.syncthing.enable = true;

  # macOS 10.9 guest (docs/macos-vm.md). Nothing runs until `macos-vm-fetch`
  # pulls the installer; the mixin only adds the two commands and the KVM
  # ignore_msrs option.
  kyan.macosVm.enable = true;

  # Remote-builder key for the e1504g (nix.buildMachines in
  # systems/e1504g/default.nix). Its root connects here as kyandesutter over
  # Tailscale to run builds. Force-commanded to `nix-daemon --stdio` (all
  # ssh-ng needs) and `restrict`ed, so the key can build but never open a
  # shell, forward ports, or run anything else.
  users.users.kyandesutter.openssh.authorizedKeys.keys = [
    ''command="/run/current-system/sw/bin/nix-daemon --stdio",restrict ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE68KT/5PWD5x1vVv2GiXcT2KlDdnl1WPH1JTEPnGpZO nix-builder@e1504g''
  ];

  # Let the e1504g reach the builder over the home LAN too (its buildMachines
  # lists 192.168.86.95 as the fallback when tailscale is down). Sshd is
  # otherwise only reachable via the trusted tailscale0 interface.
  services.openssh.openFirewall = true;

  home-manager.users.kyandesutter = {
    imports = [
      self.homeModules.kyandesutter
      self.homeModules.kyandesutter-linux
    ];
  };

  # Set once at install and never change (matches the macbook's pattern).
  system.stateVersion = "25.11";
}
