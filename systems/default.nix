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
}
