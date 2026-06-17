{
  # Linux/NixOS-only home mixins (Hyprland desktop). Wired on the g815 host via
  # self.homeModules.kyandesutter-linux.
  imports = [
    ./mixins/hyprland.nix
    ./mixins/alttab.nix
    ./mixins/caelestia.nix
    ./mixins/helium.nix
    ./mixins/spicetify.nix
  ];
}
