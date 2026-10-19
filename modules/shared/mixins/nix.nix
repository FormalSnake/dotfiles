{
  # Determinate owns Nix itself: see modules/darwin/mixins/core/determinate.nix
  # (determinateNix.enable = true implicitly disables nix-darwin's nix.* mgmt).
  nixpkgs.config = {
    allowUnfree = true;
  };
}
