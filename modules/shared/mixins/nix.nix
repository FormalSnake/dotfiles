{
  # Determinate owns Nix itself: see modules/darwin/mixins/determinate.nix
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

    # The tailnet admin panel flags every host on 1.98.x as running a version
    # with a known security vulnerability and asks for 1.102.2. nixpkgs master
    # carries that bump (2026-08-05) but the nixpkgs-unstable branch we track is
    # still on 1.98.10, so pin the newer source here instead of waiting for the
    # channel. Hashes and the two extra skipped tests are copied verbatim from
    # master's pkgs/by-name/ta/tailscale/package.nix (those tests run
    # `go test -race`, which needs cgo, and we build with CGO_ENABLED=0).
    # Drop this overlay once nixpkgs-unstable ships >= 1.102.2.
    (final: prev: {
      tailscale = prev.tailscale.overrideAttrs (finalAttrs: old: {
        version = "1.102.2";
        src = prev.fetchFromGitHub {
          owner = "tailscale";
          repo = "tailscale";
          tag = "v${finalAttrs.version}";
          hash = "sha256-vqNShvER4jT+8WJCcaSVboXPEP6S3QacmkC39tJkR4g=";
        };
        vendorHash = "sha256-amKkUPszyhG4N5ZtrB01swBACYq76raSS+SQRneLmwc=";
        checkFlags = map (
          builtins.replaceStrings
            [ "-skip=^" ]
            [ "-skip=^TestRaceAttributedToPassingTest$|^TestRaceSuppressesFlakyRetry$|^" ]
        ) old.checkFlags;
      });
    })

    # curl-cffi 0.15.0 pins four tests to curl's old error strings and cookie
    # behaviour; the curl bump in nixpkgs-unstable (2026-08-19) changed both, so
    # the test suite fails and takes yt-dlp (and everything downstream of it:
    # mpv, celluloid, formalshell) with it. Deselect just those four. Drop this
    # overlay once nixpkgs ships a curl-cffi whose tests pass against the
    # packaged curl.
    (final: prev: {
      pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
        (pyfinal: pyprev: {
          curl-cffi = pyprev.curl-cffi.overrideAttrs (old: {
            disabledTests = (old.disabledTests or [ ]) ++ [
              "test_verify"
              "test_delete_cookies"
            ];
          });
        })
      ];
    })
  ];
}
