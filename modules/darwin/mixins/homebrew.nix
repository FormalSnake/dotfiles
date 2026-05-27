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
      # Inventory verified in Phase 8 — escalate cleanup to "uninstall".
      # Anything installed but not declared in systems/macbook/homebrew.nix
      # will be uninstalled on switch. Use "zap" later to also remove leftover
      # data dirs.
      autoUpdate = true;
      upgrade = false;
      cleanup = "uninstall";
    };

    caskArgs = {
      # `no_quarantine` was removed in Homebrew 4.5+ — passing it now errors.
      require_sha = false;
    };

    global = {
      autoUpdate = true;
      brewfile = true;
    };
  };
}
