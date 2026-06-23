{ inputs, ... }:
{
  # CanaryCode (CanaryCoders/CanaryCodeCli) — our own fast, minimal terminal
  # coding agent. Installed from the upstream flake's home-manager module
  # (nixpkgs follows ours); the package is the prebuilt per-system release binary
  # with self-update disabled by the wrapper, so it's safe under Nix's immutable
  # store. `settings` left null → `canarycode` manages its own ~/.canarycode config.
  imports = [ inputs.canarycode.homeManagerModules.default ];

  programs.canarycode.enable = true;
}
