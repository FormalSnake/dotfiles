{ inputs, ... }:
{
  flake.nixosModules.default = {
    imports = [
      # CachyOS kernel overlay + binary cache + git scx schedulers.
      inputs.chaotic.nixosModules.default
      # Declarative Flatpak (base service in ./mixins/desktop/flatpak.nix).
      inputs.nix-flatpak.nixosModules.nix-flatpak
      ../shared
      ./mixins/core/nix.nix
      ./mixins/core/storage-gc.nix
      ./mixins/core/users.nix
      ./mixins/core/home-manager.nix
      ./mixins/core/locale.nix
      ./mixins/core/networking.nix
      ./mixins/core/agenix.nix
      ./mixins/core/boot.nix
      ./mixins/core/plymouth
      ./mixins/core/chime
      ./mixins/tuning/oomd.nix
      ./mixins/hardware/firmware.nix
      ./mixins/hardware/smartd.nix
      ./mixins/tuning/systemd-tuning.nix
      ./mixins/tuning/scx.nix
      ./mixins/tuning/ananicy.nix
      ./mixins/tuning/irqbalance.nix
      ./mixins/hardware/graphics.nix
      ./mixins/hardware/nvidia.nix
      ./mixins/hardware/audio.nix
      ./mixins/hardware/bluetooth.nix
      ./mixins/hardware/mouse.nix
      ./mixins/desktop/hyprland.nix
      ./mixins/desktop/kde
      ./mixins/desktop/online-accounts.nix
      ./mixins/hardware/dualsense.nix
      ./mixins/hardware/streamdeck.nix
      ./mixins/gaming/minecraft.nix
      ./mixins/gaming/waylandcraft.nix
      ./mixins/gaming/roblox.nix
      ./mixins/gaming
      ./mixins/hardware/asus.nix
      ./mixins/tuning/tuned.nix
      ./mixins/hardware/phone-integration.nix
      ./mixins/hardware/usbflux.nix
      ./mixins/hardware/printing.nix
      ./mixins/desktop/flatpak.nix
      ./mixins/services/nordvpn.nix
      ./mixins/desktop/onepassword.nix
      ./mixins/desktop/lynk-browser.nix
      ./mixins/services/syncthing.nix
      ./mixins/core/geolocation.nix
      ./mixins/core/nix-ld.nix
      ./mixins/services/macos-vm.nix
      ./mixins/services/docker.nix
      ./profiles
    ];
  };
}
