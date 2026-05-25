{ inputs, ... }:
{
  imports = [ inputs.nix-homebrew.darwinModules.nix-homebrew ];

  # Manage the Homebrew install itself
  nix-homebrew = {
    enable = true;
    enableRosetta = true;
    user = "kyandesutter";
    autoMigrate = true;
  };

  # Declarative Homebrew package management on top of that install
  homebrew = {
    enable = true;

    onActivation = {
      # SAFE defaults for first switch — flip to autoUpdate=true / upgrade=true / cleanup="zap"
      # once the declared inventory is fully accurate.
      autoUpdate = false;
      upgrade = false;
      cleanup = "none";
    };

    caskArgs = {
      no_quarantine = true;
      require_sha = false;
    };

    global = {
      autoUpdate = false;
      brewfile = true;
    };
  };
}
