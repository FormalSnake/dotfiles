{ inputs, config, lib, ... }:
{
  imports = [ inputs.nix-homebrew.darwinModules.nix-homebrew ];

  # Homebrew 6 (HOMEBREW_REQUIRE_TAP_TRUST) refuses formulae/casks from
  # untrusted third-party taps. Trust lives in a per-user trust.json whose
  # location depends on the environment ($XDG_CONFIG_HOME vs ~/.homebrew), so a
  # manual `brew trust` from an interactive shell can land in a different store
  # than the one activation's `sudo --user … brew bundle` reads — which is why
  # trusting kept "not sticking". Re-trust every declared tap in the activation
  # environment itself, right before the homebrew step runs (preActivation is
  # ordered ahead of it), so trust is declarative and self-healing.
  system.activationScripts.preActivation.text =
    lib.mkIf (config.homebrew.taps != [ ]) ''
      sudo --user=${lib.escapeShellArg config.homebrew.user} ${config.homebrew.prefix}/bin/brew trust --taps ${
        lib.escapeShellArgs (map (t: if lib.isString t then t else t.name) config.homebrew.taps)
      } || true
    '';

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
      upgrade = true;
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
