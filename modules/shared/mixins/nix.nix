{
  # Determinate Nix manages its own daemon + nix.conf. We opt nix-darwin OUT of
  # touching Nix itself; per-user/per-system Nix settings go in /etc/nix/nix.custom.conf.
  nix.enable = false;

  nixpkgs.config = {
    allowUnfree = true;
  };
}
