{ inputs, self, ... }:
{
  flake.darwinConfigurations = {
    macbook = inputs.nix-darwin.lib.darwinSystem {
      specialArgs = { inherit inputs self; };
      modules = [
        self.darwinModules.default
        ./macbook
      ];
    };
  };

  flake.nixosConfigurations = {
    g815 = inputs.nixpkgs.lib.nixosSystem {
      specialArgs = { inherit inputs self; };
      modules = [
        self.nixosModules.default
        ./g815
      ];
    };
  };
}
