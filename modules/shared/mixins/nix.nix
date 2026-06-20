{
  # Determinate owns Nix itself — see modules/darwin/mixins/determinate.nix
  # (determinateNix.enable = true implicitly disables nix-darwin's nix.* mgmt).
  nixpkgs.config = {
    allowUnfree = true;
  };

  nixpkgs.overlays = [
    # pi-coding-agent 0.78.0 dropped its koffi dependency (vendored native
    # helper instead), so the postInstall cleanup `find "$nm/koffi/build/koffi"`
    # hits a path that no longer exists and exits 1, aborting the build under
    # set -e. Pre-create the (empty) dir so that obsolete find is a harmless
    # no-op. Remove once nixpkgs drops/guards the koffi cleanup upstream.
    # Track nixpkgs' pi-coding-agent package (pkgs/by-name/pi/pi-coding-agent)
    # and drop this overlay once its postInstall no longer references the koffi
    # cleanup.
    (final: prev: {
      pi-coding-agent = prev.pi-coding-agent.overrideAttrs (old: {
        postInstall = builtins.replaceStrings
          [ ''find "$nm/koffi/build/koffi" -mindepth 1 -maxdepth 1 -type d'' ]
          [ ''mkdir -p "$nm/koffi/build/koffi"; find "$nm/koffi/build/koffi" -mindepth 1 -maxdepth 1 -type d'' ]
          old.postInstall;
      });
    })
  ];
}
