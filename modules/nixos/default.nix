{ inputs, ... }:
{
  flake.nixosModules.default = {
    imports = [
      # CachyOS kernel overlay + binary cache + git scx schedulers.
      inputs.chaotic.nixosModules.default
      # Declarative Flatpak (base service in ./mixins/flatpak.nix).
      inputs.nix-flatpak.nixosModules.nix-flatpak
      ../shared
      ./mixins/nix.nix
      ./mixins/users.nix
      ./mixins/home-manager.nix
      ./mixins/locale.nix
      ./mixins/networking.nix
      ./mixins/agenix.nix
      ./mixins/boot.nix
      ./mixins/oomd.nix
      ./mixins/firmware.nix
      ./mixins/systemd-tuning.nix
      ./mixins/scx.nix
      ./mixins/ananicy.nix
      ./mixins/graphics.nix
      ./mixins/nvidia.nix
      ./mixins/audio.nix
      ./mixins/bluetooth.nix
      ./mixins/mouse.nix
      ./mixins/hyprland.nix
      ./mixins/online-accounts.nix
      ./mixins/steam.nix
      ./mixins/dualsense.nix
      ./mixins/minecraft.nix
      ./mixins/roblox.nix
      ./mixins/comms.nix
      ./mixins/asus.nix
      ./mixins/tuned.nix
      ./mixins/phone-integration.nix
      ./mixins/usbflux.nix
      ./mixins/airplay.nix
      ./mixins/flatpak.nix
      ./mixins/nordvpn.nix
      ./mixins/onepassword.nix
      ./mixins/syncthing.nix
      ./mixins/geolocation.nix
      ./mixins/nix-ld.nix
      ./mixins/macos-vm.nix
      ./profiles
    ];
  };
}
